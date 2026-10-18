import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/agent_call.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:uuid/uuid.dart';

/// The chat of the user and the agent about one screen.
///
/// Every run reads the screen's agent list again. When a run finishes, the
/// calls of listed methods run, and the next run takes their answers to the
/// agent at once. A call that needs approval shows as an [ApprovalRequest]
/// instead, and the next run waits for the user. Any change the surface's
/// `changes` reports after the card shows invalidates it for good.
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
      (_) => _invalidateCards(),
    );
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<Map<String, Object?>>? _runSubscription;
  final _items = <ChatItem>[];
  final _queuedMessages = <String>[];
  final _history = <Map<String, Object?>>[];
  var _threadId = const Uuid().v4();

  /// Null when no run is open, and once the session is disposed.
  Run? _run;

  /// The calls of the last run, until their answers go out.
  var _calls = <ToolCall>[];
  var _contextWhenCardsShowed = '';

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
  /// since the card showed, invalidates it instead. Does nothing unless
  /// [request] is pending, or while [isRunning] (an approved method runs).
  void approve(ApprovalRequest request) {
    if (_pendingApprovalCall(request) case final call?) {
      // `changes` may not report every value the agent sees.
      if (_context() == _contextWhenCardsShowed) {
        _decide(call, .approved);
        unawaited(_runApproved(call));
      } else {
        _invalidateCards();
      }
    }
  }

  /// Tells the agent the user rejected [request], at once when every other
  /// call of its turn has an answer. Does nothing unless [request] is
  /// pending, or while [isRunning] (an approved method runs).
  void reject(ApprovalRequest request) {
    if (_pendingApprovalCall(request) case final call?) {
      _decide(call, .rejected);
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
    for (final call in _calls) {
      if (call.pending) {
        _decide(call, .cancelled);
      }
    }
    _history.addAll([
      for (final call in _calls)
        toolAnswer(call.id, call.answer ?? ToolAnswer.cancelled),
      if (text case final message?) userMessage(const Uuid().v4(), message),
    ]);
    _calls = [];
    try {
      final run = _run = Run(AgentListing.of(_surface));
      final input = runInput(
        threadId: _threadId,
        runId: const Uuid().v4(),
        messages: [..._history],
        listing: run.listing,
      );
      _runSubscription = _connection
          .run(input)
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
        final message = AgentMessage(
          '${run.texts[messageId]?.text ?? ''}$delta',
        );
        if (run.texts[messageId] case final shown?) {
          _items[_items.lastIndexOf(shown)] = message;
        } else {
          _items.add(message);
        }
        run.texts[messageId] = message;
        notifyListeners();
      // A call of a tool the listing does not list runs on the server.
      case ToolCallStarted(:final toolCallId, :final name)
          when run.listing.lists(name):
        run.calls[toolCallId] = ToolCall(toolCallId, name);
      case ToolCallArgs(:final toolCallId, :final delta):
        run.calls[toolCallId]?.arguments += delta;
      case RunFinished():
        run.ended = true;
        unawaited(_finish(run));
      case RunFailed(:final code, :final message):
        run.ended = true;
        // ADK never saw this run's calls answered, so they stay out of the
        // history.
        _history.addAll(run.assistantTexts);
        _runFailed(AgentRunException(code, message), .current);
      case _:
    }
  }

  Future<void> _finish(Run run) async {
    _calls = [...run.calls.values];
    _history.addAll([
      ...run.assistantTexts,
      for (final call in _calls)
        assistantToolCall(call.id, call.tool, call.argumentsJson),
    ]);
    try {
      await _answerCalls(run);
      await _showCards(run);
    } catch (err, st) {
      _runFailed(err, st);
      return;
    }
    if (_run == run) {
      _startNextRun();
    }
  }

  Future<void> _answerCalls(Run run) async {
    for (final call in _calls) {
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

  Future<void> _showCards(Run run) async {
    final awaitingApproval = _calls
        .where((call) => call.answer == null)
        .toList();
    if (awaitingApproval.isEmpty || run.stopped || _run != run) {
      return;
    }
    _contextWhenCardsShowed = _context();
    // Lets the changes of the calls that ran arrive before the cards show, so
    // they invalidate nothing.
    await Future<void>.delayed(.zero);
    if (_run == run && !run.stopped) {
      for (final call in awaitingApproval) {
        _items.add(call.ask(run.listing.description(call.tool)));
      }
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
    final Map<String, Object?> arguments;
    final Object? result;
    final ToolAnswer answer;
    try {
      arguments = jsonDecode(call.argumentsJson) as Map<String, Object?>;
      result = await run.listing.call(
        call.tool,
        arguments,
        approved: call.approved,
      );
      answer = .returned(result);
    } on ToolCallRefused catch (refusal) {
      return .refused(refusal.message);
    } catch (err, st) {
      // The agent's bad input. A RangeError is a bug, so it is reported.
      if (err is ArgumentError && err is! RangeError) {
        return .refused('$err');
      }
      _report(err, st);
      return .failed(err);
    }
    if (_run == run) {
      try {
        _onAgentCall?.call(
          AgentCall(tool: call.tool, arguments: arguments, result: result),
        );
      } catch (err, st) {
        _report(err, st);
      }
    }

    return answer;
  }

  ToolCall? _pendingApprovalCall(ApprovalRequest request) {
    if (isRunning) {
      return null;
    }

    return _calls
        .where((call) => call.request == request && call.pending)
        .firstOrNull;
  }

  void _decide(ToolCall call, ApprovalStatus status) {
    if (call.request case final request?) {
      final decided = request.withStatus(status);
      _items[_items.indexOf(request)] = decided;
      call
        ..request = decided
        ..answer = switch (status) {
          .rejected => ToolAnswer.rejected,
          .cancelled => ToolAnswer.cancelled,
          .invalidated => ToolAnswer.invalidated,
          .pending || .approved => null,
        };
    }
  }

  void _invalidateCards() {
    final pending = _calls.where((call) => call.pending).toList();
    if (pending.isNotEmpty) {
      for (final call in pending) {
        _decide(call, .invalidated);
      }
      notifyListeners();
    }
  }

  String _context() => jsonEncode(AgentListing.of(_surface).context);

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
    // What ADK kept of the run is unknown, so the chat moves to a new thread.
    _threadId = const Uuid().v4();
    _history.clear();
    _startNextRun();
  }

  /// Starts the run of the next queued message or, unless the user stopped,
  /// a run with only the answers once every call has one.
  void _startNextRun() {
    final answersOnly =
        !isStopping &&
        _calls.isNotEmpty &&
        _calls.every((call) => call.answer != null);
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
