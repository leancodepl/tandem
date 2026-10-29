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
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/ag_ui_thread.dart';
import 'package:tandem/src/session/app_notes.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/message_queue.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/run_method.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tandem_thread.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:tandem/src/session/view_tool.dart';
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
/// the chat to a new AG-UI thread. The chat and the history belong to a
/// [TandemThread], which the next session of the screen can go on with.
///
/// The app tells the agent what happened outside the chat with [note], and
/// [wake] lets the agent take a turn on it.
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

  /// The conversation the session goes on with, a new one when null.
  TandemThread? thread,
}) extends ChangeNotifier {
  // Apps get a session from TandemScope, the one way to say how to approve.
  @internal
  this {
    _thread.claim(this);
    _stateChangesSubscription = _surface.changes.listen(
      (_) => _invalidateAndGoOn(),
    );
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<JsonObject>? _runSubscription;
  final TandemThread _thread = thread ?? TandemThread();
  List<ChatItem> get _items => _thread.items;
  AgUiThread get _agUiThread => _thread.agUiThread;
  final _queue = MessageQueue();
  final _waiting = WaitingTurns();
  final _notes = AppNotes();

  /// Null when no run is open, and once the session is disposed.
  Run? _run;

  /// The approved method that runs now, outside any run.
  Calling? _approvedCall;

  /// The view that the next run offers the agent to draw on.
  ViewTool? _view;

  /// The views refused in a row since the last message, which stop the
  /// drawing at [_maxRefusedViews].
  var _refusedViews = 0;
  static const _maxRefusedViews = 3;

  var _disposed = false;

  /// True until the first message, which checks the screen against the
  /// thread: not at the start, while the screen may still load its state.
  var _screenToCheck = true;

  /// Oldest first, also the items of the sessions before it in the thread.
  List<ChatItem> get items => UnmodifiableListView(_items);

  /// The conversation the session goes on with: the `thread` of
  /// `TandemScope`, or one of its own.
  TandemThread get thread => _thread;

  /// Whether this session still owns its thread and accepts calls.
  @internal
  bool get isActive => !_disposed;

  SessionStatus get status => switch (_run) {
    Run(stopped: true) => const Stopping(),
    Run(:final calling?) => calling,
    Run(:final backendTool, :final drawing) => Thinking(
      backendTool: backendTool,
      drawing: drawing,
    ),
    null => _approvedCall ?? _waitingStatus,
  };

  /// The state that the agent's backend keeps of the thread, such as the
  /// steps of its plan, as the backend streams it: a `STATE_SNAPSHOT`
  /// replaces it and a `STATE_DELTA` patches it, during a run and after a
  /// Stop too. Every run sends it back. Empty until the backend sends one,
  /// and again in a new thread. A state event that does not fit is
  /// reported, and the state stays as it was. The snapshot and its nested
  /// maps and lists are immutable, and stay the same until a state update.
  JsonObject get agentState => _agUiThread.agentState.value;

  /// Sends [text], trimmed; does nothing when it is empty or the session is
  /// disposed. The message shows at once, and its run starts when no other
  /// run is open. A request that waits for the user is cancelled.
  void send(String text) {
    final message = text.trim();
    if (message.isEmpty || _disposed) {
      return;
    }
    _post(UserMessage(message));
    _waiting.cancelShownOfOthers().forEach(_showDecision);
    if (!_isBusy) {
      _start();
    }
    notifyListeners();
  }

  /// Tells the agent [text] about what happened in the app outside the
  /// chat, such as what the user did on the screen. The agent reads the
  /// latest notes with every run, without a message in the chat. Does
  /// nothing once the session is disposed.
  void note(String text) {
    if (!_disposed) {
      _notes.add(.text(text));
    }
  }

  /// Lets the agent take a turn without the user, such as on a [note]. It
  /// gets a short [UserMessage] that says the app sent it, with `fromApp`
  /// set, so the chat can hide it. The message never decides for the user:
  /// it waits while a run is open or a request waits, and goes with the next
  /// run. When the user stops the run it waited for, it waits for the user's
  /// next message. Does nothing once the session is disposed.
  void wake() {
    if (_disposed) {
      return;
    }
    _post(
      const UserMessage(
        'The app sent this, not the user. Something happened in the app: '
        'read app_notes in your context and act on it if it needs you.',
        fromApp: true,
      ),
    );
    if (status is Idle) {
      _start();
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
    _invalidateAndGoOn();
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

  /// Moves the chat to a new AG-UI thread: the next message goes without the
  /// earlier history, such as after a [RunFailed] whose `code` says the
  /// history no longer fits the model. The items stay, with a
  /// [ChatNoticeKind.startedOver] notice, and requests that wait are
  /// cancelled. A message that never reached the agent goes with the next
  /// one. Does nothing while a run is open, or once disposed.
  void startOver() {
    if (_isBusy || _disposed) {
      return;
    }
    _waiting.cancelAll().forEach(_showDecision);
    // The new thread has no calls to answer.
    _waiting.closeAgentTurn();
    _startThreadOver();
    notifyListeners();
  }

  /// Cancels the requests that wait, so a later decision throws. Nothing runs,
  /// goes to the agent or notifies after it. The thread keeps the answers of
  /// the agent's turn for the next session, or moves to a new AG-UI thread
  /// when a run is open or an approved method runs.
  @override
  void dispose() {
    letGoOfThread();
    super.dispose();
  }

  /// Lets the thread go as [dispose] does, without disposing, such as when a
  /// newer session takes it. Does nothing the second time.
  @internal
  void letGoOfThread() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _waiting.cancelAll().forEach(_showDecision);
    if (_isBusy) {
      // The backend may finish the run, and the method its call, where the
      // app never sees it.
      _startThreadOver();
    } else {
      _closeTurn();
      _agUiThread.leave(_seesNow);
    }
    _thread.release(this);
    _run = null;
    unawaited(_runSubscription?.cancel());
    unawaited(_stateChangesSubscription.cancel());
    // A new scope can claim the thread while a sibling widget builds.
    scheduleMicrotask(() {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  /// What the agent works on.
  @internal
  AgentSurface get surface => _surface;

  /// The last call of [caller] that asked the user, null before the first.
  @internal
  ToolCall? lastAsked(Caller caller) => _waiting.lastAsked(caller);

  /// Whether the screen asks the user to approve, unlike `approvals: .none()`.
  @internal
  bool get asksForApproval => _asksForApproval();

  /// Offers the agent [view] to draw on, from the next run on.
  @internal
  void attach(ViewTool view) => _view = view;

  /// Stops offering [view], from the next run on.
  @internal
  void detach(ViewTool view) {
    if (identical(view, _view)) {
      _view = null;
    }
  }

  /// Calls [tool] for [caller], such as a coding agent through
  /// `TandemBridge`. The call stays out of the agent's history, and `onEvent`
  /// hears of its return as of the agent's own calls. Throws a [StateError]
  /// when the agent list does not fit the generated code.
  ///
  /// With [autoApprove], the call runs at once, approved in advance.
  /// Otherwise a call that needs approval waits for the user as an
  /// [ApprovalRequest], which shows once the session is idle. One call of
  /// [caller] waits at a time: the same call waits for the same answer, and
  /// another is refused. The paths of [arguments] point at what [seen] read,
  /// such as the data a view was drawn with, or at the list now.
  @internal
  Future<ToolAnswer> callFor(
    Caller caller,
    String tool,
    JsonObject arguments, {
    bool autoApprove = false,
    AgentListing? seen,
  }) {
    // The in-app agent's calls come with its runs.
    assert(caller != .inAppAgent, 'callFor is for callers outside a run.');
    if (_disposed) {
      return Future.value(.refused('This session no longer owns its thread.'));
    }
    final listing = seen ?? AgentListing.of(_surface);
    final needsApproval = listing.needsApproval(tool);
    if (needsApproval && !autoApprove) {
      final call = ToolCall(
        const Uuid().v4(),
        tool,
        listing.description(tool),
        caller: caller,
      )..arguments = jsonEncode(arguments);
      if (_freeze(call, listing) case final answer?) {
        return Future.value(answer);
      }
      return _waitForUser(call);
    }
    return _callMethod(
      listing,
      tool,
      WrittenArguments(arguments),
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
      return ToolAnswer.noApprovals;
    }
    _waiting.ask(call, _seesNow);
    if (status is Idle) {
      _showNextRequest();
    }
    return await call.answered;
  }

  void _post(UserMessage message) {
    _refusedViews = 0;
    if (_screenToCheck) {
      _screenToCheck = false;
      _startOverIfScreenChanged();
    }
    _items.add(message);
    _queue.add(message);
  }

  void _start() {
    _closeTurn();
    _open();
  }

  // A thread goes on only with the screen it left, so the agent never works
  // from a history that the screen no longer shows.
  void _startOverIfScreenChanged() {
    if (_agUiThread.seenAtLeave case final seen? when seen != _seesNow) {
      _startThreadOver();
    }
  }

  void _startThreadOver() {
    _agUiThread.startOver();
    _items.add(const ChatNotice(.startedOver));
  }

  void _closeTurn() {
    final turn = _waiting.closeAgentTurn();
    turn.cancelUndecided().forEach(_showDecision);
    _agUiThread.addAnswers(turn);
  }

  void _open() {
    try {
      final listing = AgentListing.of(_surface);
      final run = _run = Run(listing, view: _offeredView(listing));
      final input = _agUiThread.input(
        tools: run.tools,
        context: [...run.listing.context, ?_notes.offer()],
        userText: _queue.text,
      );
      _runSubscription = _connection
          .run(input)
          .listen(
            (json) {
              try {
                _handleEvent(run, decodeAgUiEvent(json));
              } catch (err, st) {
                _abort(run, err, st);
              }
            },
            onError: (Object err, StackTrace st) {
              report(err, st);
              _connectionLost(run);
            },
            onDone: () => _connectionLost(run),
            cancelOnError: true,
          );
      _queue.sent();
      _agUiThread.wentOut();
    } catch (err, st) {
      // The run never went out, so its messages go with the next one.
      _queue.carry();
      _runFailed(err, st);
    }
  }

  void _handleEvent(Run run, AgentEvent event) {
    if (_run != run || run.ended) {
      return;
    }
    switch (event) {
      case final TextDelta text when !run.stopped:
        _showText(run.write(text));
      // A call of a tool the run does not offer runs on the server.
      case final ToolCallStarted start:
        run.startTool(start);
        notifyListeners();
      case final ToolCallArgs arguments:
        run.addArguments(arguments);
      case final ToolCallResult result:
        run.finishTool(result);
        notifyListeners();
      case StateSnapshot(:final snapshot):
        _changeAgentState(() => _agUiThread.agentState.replace(snapshot));
      case StateDelta(:final delta):
        _changeAgentState(() => _agUiThread.agentState.patch(delta));
      case RunFinished(outcome: .cancelled):
        run.ended = true;
        _notes.read();
        stop();
        if (_run != run) {
          return;
        }
        _recordRun(run);
        _endRunAndGoOn();
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
        _notes.read();
        unawaited(_finish(run));
      case RunError(:final code, :final message):
        run.ended = true;
        _agUiThread.addFailedRun(run);
        _runFailed(AgentRunException(code, message), .current);
      case _:
    }
  }

  // A backend's state that does not fit fails no run.
  void _changeAgentState(void Function() change) {
    try {
      change();
      notifyListeners();
    } on FormatException catch (err, st) {
      report(err, st);
    }
  }

  Turn _recordRun(Run run) {
    _agUiThread.addRun(run);
    return _waiting.startAgentTurn(run.calls.values);
  }

  Future<void> _finish(Run run) async {
    final turn = _recordRun(run);
    try {
      _invalidateIfSeesChanged();
      await _answerCalls(run, turn);
      if (!run.stopped && _run == run) {
        _askUser(turn, seen: run.listing, seesChanged: run.seesChanged);
      }
    } catch (err, st) {
      _runFailed(err, st);
      return;
    }
    if (_run == run) {
      _endRunAndGoOn();
    }
  }

  Future<void> _answerCalls(Run run, Turn turn) async {
    for (final call in turn.calls) {
      if (run.stopped || _run != run) {
        return;
      }
      final arguments = call.objectArguments;
      if (arguments == null) {
        call.answerWith(ToolAnswer.argumentsNotAnObject);
      } else if (run.view case final view? when call.tool == ViewTool.name) {
        call.answerWith(_show(view, arguments));
      } else if (!run.listing.needsApproval(call.tool)) {
        run.calling = Calling(call.tool, approved: false);
        notifyListeners();
        if (run.stopped) {
          return;
        }
        call.answerWith(
          await _callMethod(
            run.listing,
            call.tool,
            WrittenArguments(arguments),
            caller: call.caller,
            approved: false,
          ),
        );
        run.calling = null;
        _invalidateIfSeesChanged();
      }
    }
  }

  // A model that never draws a view that fits would try again on every run.
  ToolAnswer _show(OfferedView view, JsonObject arguments) {
    if (_refusedViews >= _maxRefusedViews) {
      return ToolAnswer.drawingStopped;
    }
    final answer = identical(view.tool, _view)
        ? view.tool.show(arguments)
        : ToolAnswer.refused('No view is on the screen now.');
    _refusedViews = answer.status == .shown ? 0 : _refusedViews + 1;
    return _refusedViews < _maxRefusedViews
        ? answer
        : ToolAnswer.drawingStopped;
  }

  void _askUser(
    Turn turn, {
    required AgentListing seen,
    required bool seesChanged,
  }) {
    if (!_asksForApproval()) {
      _refuseApprovals(turn);
    } else if (seesChanged) {
      // The agent asked about what it has not seen.
      turn.invalidateUndecided();
    } else {
      for (final call in turn.undecided) {
        if (_freeze(call, seen) case final answer?) {
          call.answerWith(answer);
        }
      }
      turn.ask(_seesNow);
    }
  }

  /// Reads the arguments of [call] before it asks the user, every path at
  /// the value it points at in [seen] and still holds, so the user approves
  /// what the method gets. Returns the refusal of arguments that do not fit,
  /// or, for another error, such as a converter's bug, the failed call.
  ToolAnswer? _freeze(ToolCall call, AgentListing seen) {
    try {
      final (:args, target: _) = seen.prepare(
        call.tool,
        WrittenArguments(call.objectArguments ?? const {}),
        approved: true,
      );
      call.frozen = FrozenArguments(args.json);
      return null;
    } on ToolCallRefused catch (refusal) {
      return .refused(refusal.message);
    } catch (err, st) {
      report(err, st);
      return ToolAnswer.failed;
    }
  }

  void _refuseApprovals(Turn turn) {
    for (final call in turn.refuseUndecided()) {
      if (kDebugMode) {
        report(
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
      report(err, st);
    }
  }

  // As Calling, so a new message waits for it.
  Future<void> _runApproved(ToolCall call, Turn turn) async {
    final listing = AgentListing.of(_surface);
    _approvedCall = Calling(call.tool, approved: true);
    notifyListeners();
    call.answerWith(
      await _callMethod(
        listing,
        call.tool,
        call.frozen ?? WrittenArguments(call.objectArguments ?? const {}),
        caller: call.caller,
        approved: true,
      ),
    );
    if (_disposed) {
      return;
    }
    _invalidateIfSeesChanged();
    _approvedCall = null;
    _continueAfter(turn);
  }

  /// Goes on once a request of [turn] is decided and, when approved, its
  /// method returned. Another caller's request leaves the agent's turn as it
  /// was: its answers wait for the user's next message.
  void _continueAfter(Turn turn) =>
      _goOn(withAnswers: _waiting.isAgentTurn(turn));

  /// Runs the method behind [tool] for [caller]. Unless the session is
  /// disposed by then, the agent gets a note of an action of a view, and
  /// `onEvent` hears of the return after it, so it may wake the agent.
  Future<ToolAnswer> _callMethod(
    AgentListing listing,
    String tool,
    CallArguments arguments, {
    required Caller caller,
    required bool approved,
  }) async {
    final (:answer, :returned) = await runMethod(
      listing,
      tool,
      arguments,
      caller: caller,
      approved: approved,
      report: report,
    );
    if (_disposed) {
      return answer;
    }
    if (caller == .view) {
      _notes.add(.action(tool, returned?.arguments ?? arguments.json, answer));
    }
    if (returned case final agentCall?) {
      _emit(agentCall);
    }
    return answer;
  }

  void _emit(TandemEvent event) {
    try {
      _onEvent?.call(event);
    } catch (err, st) {
      report(err, st);
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

  /// For a change seen while a run is open or an approved method runs,
  /// which go on by themselves.
  void _invalidateIfSeesChanged() {
    if (_invalidateUnlikeNow()) {
      notifyListeners();
    }
  }

  /// For a change seen by `changes` or Approve: a request that no longer
  /// shows uncovers the next one, or the app's message that waited for it.
  void _invalidateAndGoOn() {
    if (!_invalidateUnlikeNow()) {
      return;
    }
    if (status is Idle) {
      _goOn(withAnswers: false);
    } else {
      notifyListeners();
    }
  }

  /// Invalidates the requests that saw other than what the agent sees now,
  /// and returns whether there were any. The open run notes whether it sent
  /// other than that.
  bool _invalidateUnlikeNow() {
    final run = _run;
    if (run == null && !_waiting.waitsForUser) {
      return false;
    }
    final seen = _seesNow;
    if (run != null) {
      run.seesChanged = run.seesChanged || seen != SeesSnapshot.of(run.listing);
    }
    final invalidated = _waiting.invalidateUnlike(seen)..forEach(_showDecision);
    return invalidated.isNotEmpty;
  }

  SeesSnapshot get _seesNow => .read(_surface, report: report);

  OfferedView? _offeredView(AgentListing listing) {
    final view = _view;
    if (view == null || _refusedViews >= _maxRefusedViews) return null;
    return switch (view.definition(listing)) {
      final definition? => (tool: view, definition: definition),
      null => null,
    };
  }

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
    _agUiThread.startOver();
    _queue.carry();
    unawaited(_runSubscription?.cancel());
    report(error, stack);
    _items.add(const ChatNotice(.runFailed));
    _showNextRequest();
    _emit(RunFailed(code: _codeOf(error)));
  }

  void _runFailed(Object err, StackTrace st) {
    report(err, st);
    _items.add(const ChatNotice(.runFailed));
    _endRunAndGoOn();
    _emit(RunFailed(code: _codeOf(err)));
  }

  void _connectionLost(Run run) {
    if (run.ended) {
      return;
    }
    _items.add(const ChatNotice(.connectionLost));
    _agUiThread.startOver();
    _endRunAndGoOn();
    _emit(const ConnectionLost());
  }

  /// After a Stop, the agent's answers and the app's messages wait for the
  /// user's next message.
  void _endRunAndGoOn() {
    final stopped = _run?.stopped ?? false;
    if (stopped) {
      _queue.holdAppMessages();
    }
    _run = null;
    _goOn(withAnswers: !stopped);
  }

  /// Goes on once nothing runs. A run starts when the user wrote meanwhile
  /// or, [withAnswers], every call of the agent's turn has an answer.
  /// Otherwise the next request shows, and once the session is idle, a
  /// message of the app starts a run.
  void _goOn({required bool withAnswers}) {
    assert(!_isBusy, 'Only a session where nothing runs goes on.');
    if ((withAnswers && _waiting.agentAnswersDue) || _queue.userWrote) {
      _start();
      notifyListeners();
      return;
    }
    _showNextRequest();
    // The approval callback may have approved the request that showed.
    if (_queue.appMessageWaits && status is Idle) {
      _start();
      notifyListeners();
    }
  }

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
}

bool _alwaysAsks() => true;

RunErrorCode? _codeOf(Object error) => switch (error) {
  AgentRunException(:final code) => code,
  _ => null,
};
