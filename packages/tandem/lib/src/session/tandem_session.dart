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
/// goes with the next run, after the answers. A run that breaks off starts
/// the thread over without the earlier history. The chat and the history
/// belong to a [TandemThread], which the next session of the screen can go
/// on with.
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
    _stateChangesSubscription = _surface.changes.listen((_) => _checkScreen());
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<JsonObject>? _runSubscription;
  final TandemThread _thread = thread ?? TandemThread();
  List<ChatItem> get _items => _thread.items;
  AgUiThread get _agUiThread => _thread.agUiThread;
  final _queue = MessageQueue();
  final _waiting = WaitingTurns();
  final _notes = AppNotes();
  final _drawing = ViewDrawing();

  /// Null when no run is open, and once the session is disposed.
  Run? _run;

  /// The approved call whose method runs now, outside any run.
  ToolCall? _approved;

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

  SessionStatus get status {
    if (_run case final run?) return run.status;
    if (_approved?.request case final request?) {
      return Calling(request.tool, approved: true);
    }
    if (_waiting.shown case final request?) return AwaitingApproval(request);
    return const Idle();
  }

  /// The state that the agent's backend keeps of the thread, such as the
  /// steps of its plan, as the backend streams it: a `STATE_SNAPSHOT`
  /// replaces it and a `STATE_DELTA` patches it, during a run and after a
  /// Stop too. Every run sends it back. Empty until the backend sends one,
  /// and again after a reset. A state event that does not fit is
  /// reported, and the state stays as it was. The snapshot and its nested
  /// maps and lists are immutable, and stay the same until a state update.
  JsonObject get agentState => _agUiThread.agentState.value;

  /// Sends [text], trimmed; does nothing when it is empty or the session is
  /// disposed. The message shows at once, and its run starts when no other
  /// run is open. A request that waits for the user is cancelled.
  void send(String text) {
    final message = text.trim();
    if (message.isNotEmpty) _post(UserMessage(message));
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
  void wake() => _post(
    const UserMessage(
      'The app sent this, not the user. Something happened in the app: '
      'read app_notes in your context and act on it if it needs you.',
      fromApp: true,
    ),
  );

  /// Stops the open run: its later text is hidden, none of its remaining
  /// calls runs, and no run follows it. The run is still read to its end,
  /// because ADK goes on anyway and only that keeps the thread consistent.
  /// A [StoppableAgentConnection] is also told to stop the run on its
  /// server, once, unless the server ended it already. Does nothing unless
  /// [status] is [Thinking] or [Calling] a method the user did not approve.
  void stop() {
    final run = _run;
    if (run == null || run.stopped) {
      return;
    }
    run.stop();
    notifyListeners();
    _emit(const RunStopped());
    if (_run == run) {
      unawaited(run.stopOnServer(_connection));
    }
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
    _checkScreen();
    if (_waiting.decide(_latest(request), .approved) case final call?) {
      unawaited(_runApproved(call));
    }
  }

  /// Tells the agent the user rejected [request] and cancels the rest of its
  /// turn, so the agent plans again. Does nothing when [request] is rejected
  /// already. Throws an [ApprovalNotPending] when it was approved, cancelled
  /// or invalidated.
  void reject(ApprovalRequest request) {
    if (_waiting.decide(_latest(request), .rejected) case final call?) {
      _goOn(withAnswers: call.caller == .inAppAgent);
    }
  }

  /// Whether [request] waits for the user to approve or reject it.
  bool isPending(ApprovalRequest request) => _waiting.isPending(request);

  /// Clears the local history and agent state. The items stay, with a
  /// [ChatNoticeKind.startedOver] notice, and waiting requests are cancelled.
  /// A message that never went out goes with the next one.
  ///
  /// The next run uses a new AG-UI thread unless the thread has an
  /// app-supplied id. With one, calls and unsent answers from a completed
  /// run go first. The backend may still have the conversation. Use a new
  /// [TandemThread] with a new backend id for a separate conversation.
  /// Does nothing while a run or approved method is open, or once disposed.
  void startOver() {
    if (_isBusy || _disposed) {
      return;
    }
    _closeTurn();
    _waiting.cancelAll();
    _startThreadOver(keepUnsentCalls: true);
    notifyListeners();
  }

  /// Cancels the requests that wait, so a later decision throws. Nothing runs,
  /// goes to the agent or notifies after it. The thread keeps the answers of
  /// the agent's turn for the next session, or starts over when a run or an
  /// approved method of the in-app agent is open.
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
    _waiting.cancelAll();
    if (_inAppAgentWorks) {
      // The backend may finish the run, and the method its call, where the
      // app never sees it.
      _startThreadOver();
    } else {
      _closeTurn();
      // A session that sent nothing never compared the screen, so the
      // thread keeps what the screen showed the last session that did.
      if (!_screenToCheck) {
        _agUiThread.leave(_seesNow);
      }
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

  /// Offers [view] to draw on: to the in-app agent from the next run on.
  @internal
  void attach(ViewTool view) => _drawing.attach(view);

  /// Stops offering [view]: to the in-app agent from the next run on.
  @internal
  void detach(ViewTool view) => _drawing.detach(view);

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
        id: .local(),
        tool: tool,
        description: listing.description(tool),
        caller: caller,
        argumentsJson: jsonEncode(arguments),
      );
      if (call.freeze(listing) case final answer?) {
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
      if (waiting.isSameCall(call)) {
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
    if (_disposed) return;
    _drawing.resetRefusals();
    if (_screenToCheck) {
      _screenToCheck = false;
      if (_agUiThread.seenAtLeave case final seen? when seen != _seesNow) {
        _startThreadOver(keepUnsentCalls: true);
      }
    }
    _items.add(message);
    _queue.add(message);
    if (!message.fromApp) _waiting.cancelShownOfOthers();
    final waitsForApproval = message.fromApp && _waiting.shown != null;
    if (_isBusy || waitsForApproval) {
      notifyListeners();
    } else {
      _start();
    }
  }

  void _startThreadOver({bool keepUnsentCalls = false}) {
    _agUiThread.startOver(keepUnsentCalls: keepUnsentCalls);
    _items.add(const ChatNotice(.startedOver));
  }

  void _closeTurn() => _agUiThread.addAnswers(_waiting.closeAgentTurn());

  void _start() {
    _closeTurn();
    try {
      final listing = AgentListing.of(_surface);
      final run = _run = Run(
        listing,
        chat: _items,
        view: _drawing.offer(listing),
      );
      run.input = _agUiThread.input(
        tools: run.tools,
        context: [...listing.context, ?_notes.offer()],
        userText: _queue.text,
      );
      _runSubscription = _connection
          .run(run.input)
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
    // A failure callback can let go of the thread.
    if (!_disposed) notifyListeners();
  }

  void _handleEvent(Run run, AgentEvent event) {
    if (_run != run || run.ended) {
      return;
    }
    switch (event) {
      case final RunOutput output:
        if (run.receive(output)) notifyListeners();
      case final StateUpdate update:
        if (_agUiThread.agentState.apply(update)) notifyListeners();
      case RunFinished(outcome: .unsupported):
        _abort(
          run,
          const AgentRunException(
            RunErrorCode.unsupportedOutcome,
            'Unsupported run outcome.',
          ),
          .current,
        );
      case RunFinished(:final outcome):
        run.ended = true;
        _notes.read();
        if (outcome == .cancelled) {
          stop();
          // A stop listener may have let go of the thread.
          if (_run != run) return;
          _recordRun(run);
          _endRunAndGoOn();
        } else {
          unawaited(_finish(run));
        }
      case RunError(:final code, :final message):
        run.ended = true;
        _agUiThread.addFailedRun(run);
        final error = AgentRunException(code, message);
        // A server may end a run it was told to stop with RUN_ERROR.
        if (run.toldToStop) {
          report(error, .current);
          _endRunAndGoOn();
        } else {
          _runFailed(error, .current);
        }
      case IgnoredEvent():
        break;
    }
  }

  Turn _recordRun(Run run) {
    _agUiThread.addRun(run);
    return _waiting.startAgentTurn(run.collectAppCalls());
  }

  Future<void> _finish(Run run) async {
    final turn = _recordRun(run);
    try {
      _checkScreen();
      await _answerCalls(run, turn);
      if (!run.stopped && _run == run) {
        _askUser(turn, run);
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
        call.answerWith(_drawing.show(view, arguments));
      } else if (!run.listing.needsApproval(call.tool)) {
        if (run.listing.toolNamed(call.tool) case final listed?) {
          run.calling = Calling(listed.name, approved: false);
          notifyListeners();
          // A listener may have stopped the run or let the thread go.
          if (run.stopped || _run != run) {
            return;
          }
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
        _checkScreen();
      }
    }
  }

  void _askUser(Turn turn, Run run) {
    final seesChanged = run.seesChanged;
    if (!_asksForApproval()) {
      turn.refuseApprovals();
    } else if (seesChanged) {
      // The agent asked about what it has not seen.
      turn.decideUndecided(.invalidated);
    } else {
      turn
        ..freezeArguments(run.listing)
        ..ask(_seesNow);
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
  Future<void> _runApproved(ToolCall call) async {
    final listing = AgentListing.of(_surface);
    _approved = call;
    notifyListeners();
    // A listener may have let the thread go.
    if (_disposed) {
      _approved = null;
      call.decide(.cancelled);
      return;
    }
    call.answerWith(
      await _callMethod(
        listing,
        call.tool,
        call.argumentsToRun,
        caller: call.caller,
        approved: true,
      ),
    );
    if (_disposed) {
      return;
    }
    _checkScreen();
    _approved = null;
    _goOn(withAnswers: call.caller == .inAppAgent);
  }

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

  /// A change can invalidate a request even after the screen changes back.
  /// When idle, the next request or queued app message can then proceed.
  void _checkScreen() {
    final run = _run;
    if (run == null && !_waiting.waitsForUser) return;
    final seen = _seesNow;
    run?.compareScreen(seen);
    if (!_waiting.invalidateUnlike(seen)) return;
    if (status is Idle) {
      _goOn(withAnswers: false);
    } else {
      notifyListeners();
    }
  }

  SeesSnapshot get _seesNow => .read(_surface, report: report);

  bool get _isBusy => _run != null || _approved != null;

  /// Whether a run or an approved method of the in-app agent is open, whose
  /// result the thread would miss.
  bool get _inAppAgentWorks => _run != null || _approved?.caller == .inAppAgent;

  /// The app may hold an older copy of [request], with an older status.
  ApprovalRequest _latest(ApprovalRequest request) => _items
      .whereType<ApprovalRequest>()
      .lastWhere((item) => item.key == request.key, orElse: () => request);

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
      return;
    }
    _showNextRequest();
    // The approval callback may have approved the request that showed.
    if (_queue.appMessageWaits && status is Idle) {
      _start();
    }
  }

  void _showNextRequest() {
    final request = _waiting.showNext(_items);
    notifyListeners();
    if (request != null) {
      unawaited(_ask(request));
    }
  }
}

extension ViewOutsideRuns on TandemSession {
  JsonObject? viewToolDefinition(AgentListing listing) =>
      _drawing.definitionOutsideRun(listing);

  ToolAnswer showView(JsonObject arguments) =>
      _drawing.showOutsideRun(arguments);
}

bool _alwaysAsks() => true;

RunErrorCode? _codeOf(Object error) => switch (error) {
  AgentRunException(:final code) => code,
  _ => null,
};
