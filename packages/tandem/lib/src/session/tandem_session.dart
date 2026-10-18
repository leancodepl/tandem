import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/session/ag_ui_thread.dart';
import 'package:tandem/src/session/agent_call.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/run_method.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';

/// The chat of the user and the agent about one screen.
///
/// Every run reads the screen's agent list again. When a run finishes, the
/// calls of listed methods run, and the next run takes their answers to the
/// agent at once. A call that needs approval shows as an [ApprovalRequest]
/// instead, and the next run waits for the user. The request is invalidated
/// for good once what the agent sees differs from what it saw when it asked,
/// checked on every event of the surface's `changes`.
///
/// One run is open at a time: a message sent meanwhile shows at once and
/// goes with the next run, after the answers. A run that breaks off moves
/// the chat to a new AG-UI thread.
final class TandemSession({
  required final AgentSurface _surface,
  required final AgentConnection _connection,
  final AgentCallListener? _onAgentCall,
}) extends ChangeNotifier {
  this {
    _stateChangesSubscription = _surface.changes.listen(
      (_) => _invalidateIfSeesChanged(),
    );
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<Map<String, Object?>>? _runSubscription;
  final _items = <ChatItem>[];
  final _queuedMessages = <String>[];
  final _thread = AgUiThread();

  /// Null when no run is open, and once the session is disposed.
  Run? _run;

  /// The calls of the last run, until their answers go out.
  var _turn = Turn(const []);

  /// Oldest first.
  List<ChatItem> get items => UnmodifiableListView(_items);

  /// Whether a run is open or a method the agent called is running.
  bool get isRunning => _run != null;

  /// Whether the user stopped the open run, which is read to its end.
  bool get isStopping => _run?.stopped ?? false;

  /// Whether [stop] would stop the open run. A method the user approved
  /// cannot be stopped: it runs to its end.
  bool get canStop => switch (_run) {
    Run(stopped: false, runsApprovedMethod: false) => true,
    _ => false,
  };

  /// Sends [text], trimmed; does nothing when it is empty. The message shows
  /// at once, and its run starts when no other run is open.
  void send(String text) {
    final message = text.trim();
    if (message.isEmpty) {
      return;
    }
    _items.add(UserMessage(message));
    if (isRunning) {
      _queuedMessages.add(message);
    } else {
      _start(message);
    }
    notifyListeners();
  }

  /// Stops the open run: its later text is hidden, none of its remaining
  /// calls runs, and no run follows it. The run is still read to its end,
  /// because ADK goes on anyway and only that keeps the thread consistent.
  /// Does nothing unless [canStop].
  void stop() {
    final run = _run;
    if (run == null || !canStop) {
      return;
    }
    run.stopped = true;
    if (run.texts.values.lastOrNull case final last?) {
      _items[_items.lastIndexOf(last)] = AgentMessage(last.text, stopped: true);
    } else {
      _items.add(const ChatNotice(.stopped));
    }
    notifyListeners();
  }

  /// Calls the method of [request] and, once every call of its turn has an
  /// answer, takes the answers to the agent. When what the agent sees changed
  /// since it asked, invalidates the request instead. Does nothing unless
  /// [request] is pending, or while [isRunning] (an approved method runs).
  void approve(ApprovalRequest request) {
    if (isRunning) {
      return;
    }
    // `changes` may not report every value the agent sees.
    _invalidateIfSeesChanged();
    if (_turn.approve(request) case final call?) {
      _showDecision(call);
      unawaited(_runApproved(call));
    }
  }

  /// Tells the agent the user rejected [request], at once when every other
  /// call of its turn has an answer. Does nothing unless [request] is
  /// pending, or while [isRunning] (an approved method runs).
  void reject(ApprovalRequest request) {
    if (isRunning) {
      return;
    }
    if (_turn.reject(request) case final call?) {
      _showDecision(call);
      _startNextRun();
    }
  }

  @override
  void dispose() {
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
            (json) => _handleEvent(run, .fromJson(json)),
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
    switch (event) {
      case TextDelta(:final messageId, :final delta) when !run.stopped:
        _showText(run.write(messageId, delta));
      // A call of a tool the listing does not list runs on the server.
      case ToolCallStarted(:final toolCallId, :final name)
          when run.listing.lists(name):
        run.startCall(toolCallId, name);
      case ToolCallArgs(:final toolCallId, :final delta):
        run.calls[toolCallId]?.arguments += delta;
      case RunFinished():
        run.ended = true;
        unawaited(_finish(run));
      case RunFailed(:final code, :final message):
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
      final changedWhileThinking = _seesNow != SeesSnapshot.of(run.listing);
      await _answerCalls(run, turn);
      if (!run.stopped && _run == run) {
        _askUser(turn, changedWhileThinking: changedWhileThinking);
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
        call.answer = await _execute(run, call);
      }
    }
  }

  void _askUser(Turn turn, {required bool changedWhileThinking}) {
    // The agent asked about what it has not seen.
    if (changedWhileThinking) {
      turn.invalidateWaiting();
    } else {
      _items.addAll(turn.ask(_seesNow));
    }
  }

  // Its own run: a new message waits, dispose skips the follow-up.
  Future<void> _runApproved(ToolCall call) async {
    final run = _run = Run(AgentListing.of(_surface), runsApprovedMethod: true);
    notifyListeners();
    call.answer = await _execute(run, call);
    if (_run == run) {
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
      _tellAgentCall(agentCall);
    }
    return answer;
  }

  void _tellAgentCall(AgentCall call) {
    try {
      _onAgentCall?.call(call);
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
    if (_turn.waitsForUser && _didSeesChange) {
      _turn.invalidateWaiting().forEach(_showDecision);
      notifyListeners();
    }
  }

  bool get _didSeesChange => _seesNow != _turn.seen;

  SeesSnapshot get _seesNow => .read(_surface, report: _report);

  void _showDecision(ToolCall call) {
    if (call.request case final decided?) {
      final shown = _items.indexWhere(
        (item) =>
            item is ApprovalRequest && item.toolCallId == decided.toolCallId,
      );
      _items[shown] = decided;
    }
  }

  void _runFailed(Object err, StackTrace st) {
    _report(err, st);
    _items.add(const ChatNotice(.runFailed));
    _startNextRun();
  }

  void _connectionLost(Run run) {
    if (run.ended) {
      return;
    }
    _items.add(const ChatNotice(.connectionLost));
    _thread.startOver();
    _startNextRun();
  }

  /// Starts the run of the next queued message or, unless the user stopped,
  /// a run with only the answers once every call has one.
  void _startNextRun() {
    final answersOnly = !isStopping && _turn.answered;
    _run = null;
    if (_queuedMessages.isNotEmpty) {
      _start(_queuedMessages.removeAt(0));
    } else if (answersOnly) {
      _start();
    }
    notifyListeners();
  }

  void _report(Object err, StackTrace st) => FlutterError.reportError(
    FlutterErrorDetails(exception: err, stack: st, library: 'tandem'),
  );
}
