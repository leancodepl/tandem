import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/ag_ui_event_decoder.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/session/ag_ui_thread.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/run_method.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:tandem/src/session/waiting_turns.dart';
import 'package:uuid/uuid.dart';

/// The chat of the user and the agent about one screen.
///
/// Every run reads the screen's agent list again. When a run finishes, the
/// calls of listed methods run, and the next run takes their answers to the
/// agent at once. A call that needs approval shows as an [ApprovalRequest]
/// instead, one at a time, and the next run waits for the user. A request is
/// invalidated for good once what the agent sees differs from what it saw
/// when it asked, checked on every event of the surface's `changes`.
///
/// One run is open at a time: a message sent meanwhile shows at once and
/// goes with the next run, after the answers. A run that breaks off moves
/// the chat to a new AG-UI thread.
///
/// Another caller, such as a coding agent through `TandemBridge`, calls the
/// same methods with the same checks. Its request shows once the agent's own
/// requests are decided, and its answer goes only to that caller.
final class TandemSession({
  required final AgentSurface _surface,
  required final AgentConnection _connection,
  final void Function(TandemEvent event)? _onEvent,

  /// Gets each approval request when it shows, once the session waits for
  /// it, so it can decide at once.
  final Future<void> Function(ApprovalRequest request)? _onApprovalRequest,

  /// Read when the agent asks. When it returns false, for a screen that never
  /// asks, a call that needs approval is refused to the agent and reported in
  /// debug.
  final bool Function() _asksForApproval = _alwaysAsks,
}) extends ChangeNotifier {
  // Apps get a session from TandemScope, the one way to say how to approve.
  @internal
  this {
    _stateChangesSubscription = _surface.changes.listen(
      (_) => _invalidateIfSeesChanged(),
    );
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<JsonObject>? _runSubscription;
  final _items = <ChatItem>[];
  final _queuedMessages = <String>[];
  final _thread = AgUiThread();
  final _waiting = WaitingTurns();

  /// Null when no run is open, and once the session is disposed.
  Run? _run;

  /// The approved method that runs now, outside any run.
  Calling? _approvedCall;
  var _disposed = false;

  /// Oldest first.
  List<ChatItem> get items => UnmodifiableListView(_items);

  SessionStatus get status => switch (_run) {
    Run(stopped: true) => const Stopping(),
    Run(:final calling?) => calling,
    Run() => const Thinking(),
    null => _approvedCall ?? _waitingStatus,
  };

  /// Sends [text], trimmed; does nothing when it is empty or the session is
  /// disposed. The message shows at once, and its run starts when no other
  /// run is open.
  void send(String text) {
    final message = text.trim();
    if (message.isEmpty || _disposed) {
      return;
    }
    _items.add(UserMessage(message));
    _waiting.cancelShownOfOthers().forEach(_showDecision);
    if (_isBusy) {
      _queuedMessages.add(message);
    } else {
      _start(message);
    }
    notifyListeners();
  }

  /// Stops the open run: its later text is hidden, none of its remaining
  /// calls runs, and no run follows it. The run is still read to its end,
  /// because ADK goes on anyway and only that keeps the thread consistent.
  /// Does nothing unless [status] is [Thinking] or [Calling] a method the
  /// user did not approve.
  void stop() {
    final run = _run;
    if (run == null || run.stopped) {
      return;
    }
    run.stopped = true;
    if (run.texts.values.lastOrNull case final last?) {
      _items[_items.lastIndexOf(last)] = AgentMessage(last.text, stopped: true);
    } else {
      _items.add(const ChatNotice(.stopped));
    }
    notifyListeners();
    _emit(const RunStopped());
  }

  /// Calls the method of [request]. Once it returned, the next request of
  /// the turn shows or, when every call has an answer, the answers go to the
  /// agent. Does nothing when [request] is approved already.
  ///
  /// Throws an [ApprovalNotPending] when [request] was rejected, cancelled
  /// or invalidated, and also when what the agent sees changed since it
  /// asked, which invalidates it.
  void approve(ApprovalRequest request) {
    // `changes` may not report every value the agent sees.
    _invalidateIfSeesChanged();
    final turn = _waiting.turnOf(request);
    if (turn.approve(_latest(request)) case final call?) {
      _showDecision(call);
      unawaited(_runApproved(call, turn));
    }
  }

  /// Tells the agent the user rejected [request] and cancels the rest of its
  /// turn, so the agent plans again. Does nothing when [request] is rejected
  /// already. Throws an [ApprovalNotPending] when it was approved, cancelled
  /// or invalidated.
  void reject(ApprovalRequest request) {
    final turn = _waiting.turnOf(request);
    if (turn.reject(_latest(request)) case final call?) {
      _showDecision(call);
      _continueAfter(turn);
    }
  }

  /// Whether [request] waits for the user to approve or reject it.
  bool isPending(ApprovalRequest request) =>
      _waiting.turnOf(request).isPending(request);

  /// What the agent works on.
  @internal
  AgentSurface get surface => _surface;

  /// The last call of [caller] that asked the user, null before the first.
  @internal
  ToolCall? lastAsked(Caller caller) => _waiting.lastAsked(caller);

  /// Calls [tool] for [caller], such as a coding agent through
  /// `TandemBridge`. The call stays out of the agent's history, and `onEvent`
  /// hears of its return as of the agent's own calls. Throws a [StateError]
  /// when the agent list does not fit the generated code.
  ///
  /// With [autoApprove], the call runs at once, approved in advance.
  /// Otherwise a call that needs approval waits for the user as an
  /// [ApprovalRequest], which shows once the session is idle. One call of
  /// [caller] waits at a time: the same call waits for the same answer, and
  /// another is refused.
  @internal
  Future<ToolAnswer> callFor(
    Caller caller,
    String tool,
    JsonObject arguments, {
    bool autoApprove = false,
  }) {
    final listing = AgentListing.of(_surface);
    final argumentsJson = jsonEncode(arguments);
    final needsApproval = listing.needsApproval(tool);
    if (needsApproval && !autoApprove) {
      final call = ToolCall(
        const Uuid().v4(),
        tool,
        listing.description(tool),
        caller: caller,
      )..arguments = argumentsJson;
      return _waitForUser(call);
    }
    return _callMethod(
      listing,
      tool,
      argumentsJson,
      caller: caller,
      approved: autoApprove,
    );
  }

  Future<ToolAnswer> _waitForUser(ToolCall call) async {
    if (_waiting.lastAsked(call.caller) case final waiting?
        when waiting.answer == null) {
      if (waiting.tool == call.tool && waiting.arguments == call.arguments) {
        return await waiting.answered;
      }
      return .refused(
        '${waiting.tool} waits for the user or still runs. Repeat that call '
        'to wait for its answer before you call ${call.tool}.',
      );
    }
    if (!_asksForApproval()) {
      return .refused(
        "${call.tool} needs the user's approval, but this screen has "
        'approvals: .none(). TandemBridge.enable(autoApprove: true) approves '
        'the calls of a coding agent.',
      );
    }
    _waiting.ask(call, _seesNow);
    if (status is Idle) {
      _showNextRequest();
    }
    return await call.answered;
  }

  /// Moves the chat to a new AG-UI thread: the next message goes without the
  /// earlier history, such as after a [RunFailed] whose `code` says the
  /// history no longer fits the model. The items stay, with a
  /// [ChatNoticeKind.startedOver] notice, and requests that wait are
  /// cancelled. Does nothing while a run is open, or once disposed.
  void startOver() {
    if (_isBusy || _disposed) {
      return;
    }
    _waiting.cancelAll().forEach(_showDecision);
    _waiting.agent = Turn(const []);
    _thread.startOver();
    _items.add(const ChatNotice(.startedOver));
    notifyListeners();
  }

  /// Cancels the requests that wait, so a later decision throws. Nothing runs,
  /// goes to the agent or notifies after it.
  @override
  void dispose() {
    _disposed = true;
    _waiting.cancelAll().forEach(_showDecision);
    _run = null;
    unawaited(_runSubscription?.cancel());
    unawaited(_stateChangesSubscription.cancel());
    super.dispose();
  }

  void _start([String? text]) {
    _closeTurn(text);
    _open();
  }

  void _closeTurn(String? text) {
    final turn = _waiting.agent;
    turn.cancelWaiting().forEach(_showDecision);
    _thread.addAnswers(turn, text);
    _waiting.agent = Turn(const []);
  }

  void _open() {
    try {
      final run = _run = Run(AgentListing.of(_surface));
      _runSubscription = _connection
          .run(_thread.input(run.listing))
          .listen(
            (json) {
              try {
                _handleEvent(run, decodeAgUiEvent(json));
              } catch (err, st) {
                _abort(run, err, st);
              }
            },
            onError: (Object err, StackTrace st) {
              _report(err, st);
              _connectionLost(run);
            },
            onDone: () => _connectionLost(run),
            cancelOnError: true,
          );
    } catch (err, st) {
      // The run never went out, so its messages go with the next one.
      _runFailed(err, st);
    }
  }

  void _handleEvent(Run run, AgentEvent event) {
    if (_run != run || run.ended) {
      return;
    }
    switch (event) {
      case TextDelta(:final messageId, :final delta) when !run.stopped:
        _showText(run.write(messageId, delta));
      // A call of a tool the listing does not list runs on the server.
      case ToolCallStarted(:final toolCallId, :final name)
          when run.listing.lists(name) || run.calls.containsKey(toolCallId):
        run.startCall(toolCallId, name);
      case ToolCallArgs(:final toolCallId, :final delta):
        run.calls[toolCallId]?.arguments += delta;
      case RunFinished(outcome: .cancelled):
        run.ended = true;
        stop();
        if (_run != run) {
          return;
        }
        final turn = _waiting.agent = Turn([...run.calls.values]);
        _thread.addTurn(run, turn);
        _startNextRun();
      case RunFinished(outcome: .unsupported):
        _abort(
          run,
          const AgentRunException(
            RunErrorCode.unsupportedOutcome,
            'Unsupported run outcome.',
          ),
          .current,
        );
      case RunFinished(outcome: .success):
        run.ended = true;
        unawaited(_finish(run));
      case RunError(:final code, :final message):
        run.ended = true;
        _thread.addFailedRun(run);
        _runFailed(AgentRunException(code, message), .current);
      case _:
    }
  }

  Future<void> _finish(Run run) async {
    final turn = _waiting.agent = Turn([...run.calls.values]);
    _thread.addTurn(run, turn);
    try {
      _invalidateIfSeesChanged();
      await _answerCalls(run, turn);
      if (!run.stopped && _run == run) {
        _askUser(turn, seesChanged: run.seesChanged);
      }
    } catch (err, st) {
      _runFailed(err, st);
      return;
    }
    if (_run == run) {
      _startNextRun();
    }
  }

  Future<void> _answerCalls(Run run, Turn turn) async {
    for (final call in turn.calls) {
      if (run.stopped || _run != run) {
        return;
      }
      if (!call.hasObjectArguments) {
        call.answer = .refused('The arguments must be a JSON object.');
      } else if (!run.listing.needsApproval(call.tool)) {
        run.calling = Calling(call.tool, approved: false);
        notifyListeners();
        if (run.stopped) {
          return;
        }
        call.answer = await _callMethod(
          run.listing,
          call.tool,
          call.argumentsJson,
          caller: call.caller,
          approved: false,
        );
        run.calling = null;
        _invalidateIfSeesChanged();
      }
    }
  }

  void _askUser(Turn turn, {required bool seesChanged}) {
    if (!_asksForApproval()) {
      _refuseApprovals(turn);
    } else if (seesChanged) {
      // The agent asked about what it has not seen.
      turn.invalidateWaiting();
    } else {
      turn.ask(_seesNow);
    }
  }

  void _refuseApprovals(Turn turn) {
    final refused = turn.refuseWaiting(
      'The user cannot approve calls on this screen.',
    );
    for (final call in refused) {
      if (kDebugMode) {
        _report(
          StateError(
            '${call.tool} needs approval, but this screen has approvals: '
            '.none().',
          ),
          .current,
        );
      }
    }
  }

  Future<void> _ask(ApprovalRequest request) async {
    try {
      await _onApprovalRequest?.call(request);
    } catch (err, st) {
      _report(err, st);
    }
  }

  // As Calling, so a new message waits for it.
  Future<void> _runApproved(ToolCall call, Turn turn) async {
    final listing = AgentListing.of(_surface);
    _approvedCall = Calling(call.tool, approved: true);
    notifyListeners();
    call.answer = await _callMethod(
      listing,
      call.tool,
      call.argumentsJson,
      caller: call.caller,
      approved: true,
    );
    if (_disposed) {
      return;
    }
    // Still Calling, so only _continueAfter decides what comes next.
    _invalidateIfSeesChanged();
    _approvedCall = null;
    _continueAfter(turn);
  }

  /// Goes on once a request of [turn] is decided and, when approved, its
  /// method returned. Another caller's request leaves the agent's turn as it
  /// was: its answers wait for the user's next message.
  void _continueAfter(Turn turn) =>
      _startNextRun(withAnswers: identical(turn, _waiting.agent));

  /// Runs the method behind [tool] for [caller]. `onEvent` hears of its
  /// return unless the session is disposed by then.
  Future<ToolAnswer> _callMethod(
    AgentListing listing,
    String tool,
    String argumentsJson, {
    required Caller caller,
    required bool approved,
  }) async {
    final (:answer, :returned) = await runMethod(
      listing,
      tool,
      argumentsJson,
      caller: caller,
      approved: approved,
      report: _report,
    );
    if (returned case final agentCall? when !_disposed) {
      _emit(agentCall);
    }
    return answer;
  }

  void _emit(TandemEvent event) {
    try {
      _onEvent?.call(event);
    } catch (err, st) {
      _report(err, st);
    }
  }

  void _showText(({AgentMessage? shown, AgentMessage grown}) text) {
    if (text.shown case final shown?) {
      _items[_items.lastIndexOf(shown)] = text.grown;
    } else {
      _items.add(text.grown);
    }
    notifyListeners();
  }

  void _invalidateIfSeesChanged() {
    final run = _run;
    if (run == null && !_waiting.waitsForUser) {
      return;
    }
    final seen = _seesNow;
    if (run != null) {
      run.seesChanged = run.seesChanged || seen != SeesSnapshot.of(run.listing);
    }
    final invalidated = _waiting.invalidateUnlike(seen);
    if (invalidated.isEmpty) {
      return;
    }
    invalidated.forEach(_showDecision);
    // A request that no longer shows uncovers the next one.
    if (status is Idle) {
      _showNextRequest();
    } else {
      notifyListeners();
    }
  }

  SeesSnapshot get _seesNow => .read(_surface, report: _report);

  /// A run is open, or an approved method runs.
  bool get _isBusy => _run != null || _approvedCall != null;

  SessionStatus get _waitingStatus => switch (_waiting.shown) {
    final request? => AwaitingApproval(request),
    null => const Idle(),
  };

  /// The app may hold an older copy of [request], with an older status.
  ApprovalRequest _latest(ApprovalRequest request) =>
      _items.whereType<ApprovalRequest>().lastWhere(
        (item) => item.toolCallId == request.toolCallId,
        orElse: () => request,
      );

  void _showDecision(ToolCall call) {
    if (call.request case final decided?) {
      final shown = _items.indexWhere(
        (item) =>
            item is ApprovalRequest && item.toolCallId == decided.toolCallId,
      );
      _items[shown] = decided;
    }
  }

  void _abort(Run run, Object error, StackTrace stack) {
    if (_run != run) {
      return;
    }
    run.ended = true;
    _run = null;
    _waiting.agent = Turn(const []);
    _thread.startOver();
    for (final message in _queuedMessages) {
      _thread.addAnswers(_waiting.agent, message);
    }
    _queuedMessages.clear();
    unawaited(_runSubscription?.cancel());
    _report(error, stack);
    _items.add(const ChatNotice(.runFailed));
    _showNextRequest();
    _emit(RunFailed(code: _codeOf(error)));
  }

  void _runFailed(Object err, StackTrace st) {
    _report(err, st);
    _items.add(const ChatNotice(.runFailed));
    _startNextRun();
    _emit(RunFailed(code: _codeOf(err)));
  }

  void _connectionLost(Run run) {
    if (run.ended) {
      return;
    }
    _items.add(const ChatNotice(.connectionLost));
    _thread.startOver();
    _startNextRun();
    _emit(const ConnectionLost());
  }

  /// Starts the run of the next queued message or, [withAnswers] and unless
  /// the user stopped, a run with only the answers once every call of the
  /// agent's turn has one. Otherwise shows the next request.
  void _startNextRun({bool withAnswers = true}) {
    final answersOnly =
        withAnswers && status is! Stopping && _waiting.agent.answered;
    _run = null;
    if (_queuedMessages.isNotEmpty) {
      _start(_queuedMessages.removeAt(0));
      notifyListeners();
    } else if (answersOnly) {
      _start();
      notifyListeners();
    } else {
      _showNextRequest();
    }
  }

  /// Shows the next request that waits, the agent's first, and gives it to
  /// `approvals:`.
  void _showNextRequest() {
    final request = _waiting.showNext();
    if (request != null) {
      _items.add(request);
    }
    notifyListeners();
    if (request != null) {
      unawaited(_ask(request));
    }
  }

  void _report(Object err, StackTrace st) => FlutterError.reportError(
    FlutterErrorDetails(exception: err, stack: st, library: 'tandem'),
  );
}

bool _alwaysAsks() => true;

RunErrorCode? _codeOf(Object error) => switch (error) {
  AgentRunException(:final code) => code,
  _ => null,
};
