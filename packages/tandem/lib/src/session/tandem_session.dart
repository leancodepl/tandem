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
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/ag_ui_thread.dart';
import 'package:tandem/src/session/attached_view.dart';
import 'package:tandem/src/session/call_pipeline.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_event.dart';

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
/// A coding agent's call through `TandemBridge` asks the same way, once the
/// agent's own requests are decided, and its answer goes only to the coding
/// agent.
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
      (_) => _calls.invalidateIfSeesChanged(),
    );
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<JsonObject>? _runSubscription;
  final _items = <ChatItem>[];
  final _queuedMessages = <String>[];
  final _thread = AgUiThread();
  late final _calls = CallPipeline(
    surface: _surface,
    items: _items,
    openRun: () => _run,
    decided: ({required agentTurn}) => _startNextRun(withAnswers: agentTurn),
    notify: notifyListeners,
    emit: _emit,
    onApprovalRequest: _onApprovalRequest,
    asksForApproval: _asksForApproval,
  );

  /// Null when no run is open, and once the session is disposed.
  Run? _run;
  AttachedView? _view;
  var _disposed = false;

  /// Oldest first.
  List<ChatItem> get items => UnmodifiableListView(_items);

  SessionStatus get status => switch (_run) {
    Run(stopped: true) => const Stopping(),
    Run() => _calls.calling ?? const Thinking(),
    null => _calls.status,
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
    _calls.cancelShownOutside();
    if (_busy) {
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
  void approve(ApprovalRequest request) => _calls.approve(request);

  /// Tells the agent the user rejected [request] and cancels the rest of its
  /// turn, so the agent plans again. Does nothing when [request] is rejected
  /// already. Throws an [ApprovalNotPending] when it was approved, cancelled
  /// or invalidated.
  void reject(ApprovalRequest request) => _calls.reject(request);

  /// Whether [request] waits for the user to approve or reject it.
  bool isPending(ApprovalRequest request) => _calls.isPending(request);

  /// What the agent works on.
  @internal
  AgentSurface get surface => _surface;

  /// The way in for callers outside the agent's run, such as a coding agent
  /// through `TandemBridge`.
  @internal
  OutsideCalls get calls => _calls;

  /// Offers [view]'s tool from the next run on.
  @internal
  void attach(AttachedView view) => _view = view;

  /// Stops offering [view]'s tool from the next run on.
  @internal
  void detach(AttachedView view) {
    if (identical(view, _view)) {
      _view = null;
    }
  }

  /// Moves the chat to a new AG-UI thread: the next message goes without the
  /// earlier history, such as after a [RunFailed] whose `code` says the
  /// history no longer fits the model. The items stay, with a
  /// [ChatNoticeKind.startedOver] notice, and requests that wait are
  /// cancelled. Does nothing while a run is open, or once disposed.
  void startOver() {
    if (_busy || _disposed) {
      return;
    }
    _calls.cancelAll();
    _thread.startOver();
    _items.add(const ChatNotice(.startedOver));
    notifyListeners();
  }

  /// Cancels the requests that wait, so a later decision throws. Nothing runs,
  /// goes to the agent or notifies after it.
  @override
  void dispose() {
    _disposed = true;
    _calls.dispose();
    _run = null;
    unawaited(_runSubscription?.cancel());
    unawaited(_stateChangesSubscription.cancel());
    super.dispose();
  }

  /// A run is open, or a method the user approved runs.
  bool get _busy => switch (status) {
    Idle() || AwaitingApproval() => false,
    _ => true,
  };

  void _start([String? text]) {
    _thread.addAnswers(_calls.closeTurn(), text);
    _open();
  }

  void _open() {
    try {
      final run = _run = Run(AgentListing.of(_surface), view: _view);
      _runSubscription = _connection
          .run(_thread.input(run))
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
      // A call of a tool the run does not offer runs on the server.
      case ToolCallStarted(:final toolCallId, :final name)
          when run.offers(name) || run.calls.containsKey(toolCallId):
        run.startCall(toolCallId, name);
      case ToolCallArgs(:final toolCallId, :final delta):
        run.calls[toolCallId]?.arguments += delta;
      case RunFinished(outcome: .cancelled):
        run.ended = true;
        stop();
        if (_run != run) {
          return;
        }
        _endTurn(run);
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
    _endTurn(run);
    try {
      await _calls.answerTurn(run);
    } catch (err, st) {
      _runFailed(err, st);
      return;
    }
    if (_run == run) {
      _startNextRun();
    }
  }

  void _endTurn(Run run) {
    _calls.takeTurn(run);
    _thread.addTurn(run);
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

  void _abort(Run run, Object error, StackTrace stack) {
    if (_run != run) {
      return;
    }
    run.ended = true;
    _run = null;
    _calls.dropTurn();
    _thread.startOver();
    _queuedMessages.forEach(_thread.addMessage);
    _queuedMessages.clear();
    unawaited(_runSubscription?.cancel());
    report(error, stack);
    _items.add(const ChatNotice(.runFailed));
    _calls.showNext();
    _emit(RunFailed(code: _codeOf(error)));
  }

  void _runFailed(Object err, StackTrace st) {
    report(err, st);
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
  /// the user stopped, a run with only the answers once every call has one.
  /// Otherwise shows the next request. An outside caller's decision goes on
  /// without the answers: they wait for the user's next message.
  void _startNextRun({bool withAnswers = true}) {
    final answersOnly = withAnswers && status is! Stopping && _calls.answersDue;
    _run = null;
    if (_queuedMessages.isNotEmpty) {
      _start(_queuedMessages.removeAt(0));
      notifyListeners();
    } else if (answersOnly) {
      _start();
      notifyListeners();
    } else {
      _calls.showNext();
    }
  }
}

bool _alwaysAsks() => true;

RunErrorCode? _codeOf(Object error) => switch (error) {
  AgentRunException(:final code) => code,
  _ => null,
};
