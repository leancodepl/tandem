import 'dart:async';
import 'dart:collection';

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
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/run_method.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';

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

  /// Null when no run is open, and once the session is disposed.
  Run? _run;
  var _disposed = false;

  /// The calls of the last run, until their answers go out.
  var _turn = Turn(const []);

  /// Oldest first.
  List<ChatItem> get items => UnmodifiableListView(_items);

  SessionStatus get status => switch (_run) {
    Run(stopped: true) => const Stopping(),
    Run(:final calling?) => calling,
    Run() => const Thinking(),
    null => switch (_turn.awaited) {
      final request? => AwaitingApproval(request),
      null => const Idle(),
    },
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
    if (_run != null) {
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
    if (run == null || run.stopped || (run.calling?.approved ?? false)) {
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
    if (_turn.approve(_latest(request)) case final call?) {
      _showDecision(call);
      unawaited(_runApproved(call));
    }
  }

  /// Tells the agent the user rejected [request] and cancels the rest of its
  /// turn, so the agent plans again. Does nothing when [request] is rejected
  /// already. Throws an [ApprovalNotPending] when it was approved, cancelled
  /// or invalidated.
  void reject(ApprovalRequest request) {
    if (_turn.reject(_latest(request)) case final call?) {
      _showDecision(call);
      _startNextRun();
    }
  }

  /// Whether [request] waits for the user to approve or reject it.
  bool isPending(ApprovalRequest request) => _turn.isPending(request);

  /// Cancels the requests that wait, so a later decision throws. Nothing runs,
  /// goes to the agent or notifies after it.
  @override
  void dispose() {
    _disposed = true;
    _turn.cancelWaiting().forEach(_showDecision);
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
    _turn.cancelWaiting().forEach(_showDecision);
    _thread.addAnswers(_turn, text);
    _turn = Turn(const []);
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
        _turn = Turn([...run.calls.values]);
        _thread.addTurn(run, _turn);
        _startNextRun();
      case RunFinished(outcome: .unsupported):
        _abort(
          run,
          const AgentRunException(
            'UNSUPPORTED_OUTCOME',
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
    final turn = _turn = Turn([...run.calls.values]);
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
        call.answer = await _execute(run, call);
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

  // Its own run: a new message waits, dispose skips the follow-up.
  Future<void> _runApproved(ToolCall call) async {
    final run = _run = Run(AgentListing.of(_surface))
      ..calling = Calling(call.tool, approved: true);
    notifyListeners();
    call.answer = await _execute(run, call);
    if (_run == run) {
      _invalidateIfSeesChanged();
      _startNextRun();
    }
  }

  Future<ToolAnswer> _execute(Run run, ToolCall call) async {
    final (:answer, :returned) = await runMethod(
      run.listing,
      call,
      report: _report,
    );
    if (returned case final agentCall? when _run == run) {
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
    if (_run == null && !_turn.waitsForUser) {
      return;
    }
    final seen = _seesNow;
    if (_run case final run?) {
      run.seesChanged = run.seesChanged || seen != SeesSnapshot.of(run.listing);
    }
    if (_turn.waitsForUser && seen != _turn.seen) {
      _turn.invalidateWaiting().forEach(_showDecision);
      notifyListeners();
    }
  }

  SeesSnapshot get _seesNow => .read(_surface, report: _report);

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
    _turn = Turn(const []);
    _thread.startOver();
    for (final message in _queuedMessages) {
      _thread.addAnswers(_turn, message);
    }
    _queuedMessages.clear();
    unawaited(_runSubscription?.cancel());
    _report(error, stack);
    _items.add(const ChatNotice(.runFailed));
    notifyListeners();
    _emit(const RunFailed());
  }

  void _runFailed(Object err, StackTrace st) {
    _report(err, st);
    _items.add(const ChatNotice(.runFailed));
    _startNextRun();
    _emit(const RunFailed());
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

  /// Starts the run of the next queued message or, unless the user stopped,
  /// a run with only the answers once every call has one. Otherwise shows
  /// the next request of the turn.
  void _startNextRun() {
    final answersOnly = status is! Stopping && _turn.answered;
    _run = null;
    ApprovalRequest? asked;
    if (_queuedMessages.isNotEmpty) {
      _start(_queuedMessages.removeAt(0));
    } else if (answersOnly) {
      _start();
    } else if (_turn.next() case final request?) {
      _items.add(request);
      asked = request;
    }
    notifyListeners();
    if (asked != null) {
      unawaited(_ask(asked));
    }
  }

  void _report(Object err, StackTrace st) => FlutterError.reportError(
    FlutterErrorDetails(exception: err, stack: st, library: 'tandem'),
  );
}

bool _alwaysAsks() => true;
