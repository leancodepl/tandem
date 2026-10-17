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
import 'package:uuid/uuid.dart';

// Tool answers carry their status in `content`: ag-ui-adk ignores a tool
// message's `error`, and the model reads an empty content as success.
const _cancelled = '{"status":"cancelled"}';
const _invalidated = '{"status":"invalidated"}';
// Not a bare "rejected": Gemini read that as a refusal of the system.
const _rejected = '{"status":"rejected_by_user"}';
String _refused(String reason) =>
    jsonEncode({'status': 'refused', 'reason': reason});
String _failed(Object err) => jsonEncode({'status': 'failed', 'error': '$err'});

void _report(Object err, StackTrace st) => FlutterError.reportError(
  FlutterErrorDetails(exception: err, stack: st, library: 'tandem'),
);

/// A call of a listed method that returned.
final class const AgentCall({
  /// The method's name in snake_case.
  required final String tool,
  required final Map<String, Object?> arguments,

  /// What the method returned, as JSON.
  required final Object? result,
});

/// Not called for a call that was refused or threw, nor once the session is
/// disposed.
typedef AgentCallListener = void Function(AgentCall call);

/// The chat of the user and the agent about one screen.
///
/// Every run reads the screen's agent list again. When a run finishes, the
/// calls of listed methods run, and the next run takes their answers to the
/// agent at once. A call that needs approval shows as an [ApprovalRequest]
/// instead, and the next run waits for the user. Any change `changes`
/// reports after the card shows invalidates it for good.
///
/// One run is open at a time: a message sent meanwhile shows at once and
/// goes with the next run, after the answers. A run that breaks off moves
/// the chat to a new AG-UI thread.
final class TandemSession({
  required final AgentSurface _surface,
  required Stream<Object?> changes,
  required final AgentConnection _connection,
  final AgentCallListener? _onAgentCall,
}) extends ChangeNotifier {
  this {
    _stateChangesSubscription = changes.listen(
      (_) => _invalidatePendingApprovals(),
    );
  }

  late final StreamSubscription<Object?> _stateChangesSubscription;
  StreamSubscription<Map<String, Object?>>? _runSubscription;
  final _items = <ChatItem>[];
  final _queuedMessages = <String>[];
  final _history = <Map<String, Object?>>[];
  var _threadId = const Uuid().v4();
  _Run? _run;
  var _stopping = false;

  var _calls = <_Call>[];
  var _contextWhenCardsShowed = '';

  /// Oldest first.
  List<ChatItem> get items => UnmodifiableListView(_items);

  /// Whether a run is open or a method the agent called is running.
  bool get isRunning => _run != null;

  /// Whether the user stopped the open run, which is read to its end.
  bool get isStopping => _stopping;

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
  /// Does nothing when no run is open.
  void stop() {
    final run = _run;
    if (run == null || _stopping) {
      return;
    }
    _stopping = true;
    final lastMessageId = run.messageText.keys.lastOrNull;
    if ((run.messageText[lastMessageId], run.textItemIndices[lastMessageId])
        case (final text?, final itemIndex?)) {
      _items[itemIndex] = AgentMessage(text, stopped: true);
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
        _invalidatePendingApprovals();
      }
    }
  }

  /// Tells the agent the user rejected [request], at once when every other
  /// call of its turn has an answer. Does nothing unless [request] is
  /// pending, or while [isRunning] (an approved method runs).
  void reject(ApprovalRequest request) {
    if (_pendingApprovalCall(request) case final call?) {
      _decide(call, .rejected, _rejected);
      _completeOperation(followUp: _canFollowUp);
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
        _decide(call, .cancelled, _cancelled);
      }
    }
    _history.addAll([
      for (final call in _calls) toolAnswer(call.id, call.answer ?? _cancelled),
      if (text case final message?) userMessage(const Uuid().v4(), message),
    ]);
    _calls = [];
    try {
      final listing = AgentListing.of(_surface);
      final run = _run = _Run(listing);
      final input = runInput(
        threadId: _threadId,
        runId: const Uuid().v4(),
        messages: [..._history],
        listing: listing,
      );
      _runSubscription = _connection
          .run(input)
          .listen(
            (json) => _handleEvent(run, .fromJson(json)),
            onError: (Object err, StackTrace st) {
              _report(err, st);
              _handleConnectionLost(run);
            },
            onDone: () => _handleConnectionLost(run),
            cancelOnError: true,
          );
    } catch (err, st) {
      // The run never went out, so its messages go with the next one.
      _report(err, st);
      _items.add(const ChatNotice(.runFailed));
      _completeOperation();
    }
  }

  void _handleEvent(_Run run, AgentEvent event) {
    switch (event) {
      case RunFinished():
        run.ended = true;
        unawaited(_finish(run));
      case RunFailed(:final code, :final message):
        run.ended = true;
        _report(AgentRunException(code, message), .current);
        // ADK never saw this run's calls answered, so they stay out of the
        // history.
        _history.addAll(run.assistantMessages);
        _items.add(const ChatNotice(.runFailed));
        _completeOperation();
      case _:
        if (run.read(event, showText: !_stopping) case (
          :final messageId,
          :final text,
        )) {
          final message = AgentMessage(text);
          if (run.textItemIndices[messageId] case final itemIndex?) {
            _items[itemIndex] = message;
          } else {
            run.textItemIndices[messageId] = _items.length;
            _items.add(message);
          }
          notifyListeners();
        }
    }
  }

  Future<void> _finish(_Run run) async {
    _calls = [...run.calls.values];
    _history.addAll([
      ...run.assistantMessages,
      for (final call in _calls)
        assistantToolCall(call.id, call.tool, call.argumentsJson),
    ]);
    try {
      for (final call in _calls) {
        if (_stopping) {
          break;
        }
        if (!run.listing.needsApproval(call.tool)) {
          call.answer = await _execute(run, call);
          if (_run != run) {
            return; // Disposed meanwhile.
          }
        } else if (!call.hasObjectArguments) {
          call.answer = _refused('The arguments must be a JSON object.');
        }
      }
      final callsAwaitingApproval = [
        for (final call in _calls)
          if (call.answer == null) call,
      ];
      if (!_stopping && callsAwaitingApproval.isNotEmpty) {
        _contextWhenCardsShowed = _context();
        // Lets the changes of the calls above arrive before the cards show,
        // so they invalidate nothing.
        await Future<void>.delayed(.zero);
        if (_run != run) {
          return; // Disposed meanwhile.
        }
        if (!_stopping) {
          for (final call in callsAwaitingApproval) {
            final request = ApprovalRequest(
              toolCallId: call.id,
              tool: call.tool,
              description: run.listing.description(call.tool),
              argumentsJson: call.argumentsJson,
            );
            call.request = request;
            _items.add(request);
          }
        }
      }
    } catch (err, st) {
      _report(err, st);
      _items.add(const ChatNotice(.runFailed));
      _completeOperation();
      return;
    }
    _completeOperation(followUp: _canFollowUp);
  }

  // Its own run: a new message waits, Stop and dispose skip the follow-up.
  Future<void> _runApproved(_Call call) async {
    final run = _run = _Run(AgentListing.of(_surface));
    notifyListeners();
    call.answer = await _execute(run, call);
    if (_run == run) {
      _completeOperation(followUp: _canFollowUp);
    }
  }

  Future<String> _execute(_Run run, _Call call) async {
    final Map<String, Object?> args;
    final Object? result;
    final String answer;
    try {
      args = jsonDecode(call.argumentsJson) as Map<String, Object?>;
      result = await run.listing.call(call.tool, args, approved: call.approved);
      answer = jsonEncode(result);
    } catch (err, st) {
      switch (err) {
        case ToolCallRefused(:final message):
          return _refused(message);
        // The agent's bad input. A RangeError is a bug, so it is reported.
        case ArgumentError() when err is! RangeError:
          return _refused('$err');
        case _:
          _report(err, st);
          return _failed(err);
      }
    }
    if (_run == run) {
      try {
        _onAgentCall?.call(
          AgentCall(tool: call.tool, arguments: args, result: result),
        );
      } catch (err, st) {
        _report(err, st);
      }
    }
    return answer;
  }

  _Call? _pendingApprovalCall(ApprovalRequest request) {
    if (isRunning) {
      return null;
    }
    return _calls
        .where((call) => call.request == request && call.pending)
        .firstOrNull;
  }

  void _decide(_Call call, ApprovalStatus status, [String? answer]) {
    final request = switch (call.request) {
      final request? when request.status == .pending => request,
      _ => throw StateError('The call of ${call.tool} has no pending card.'),
    };
    final updatedRequest = request.withStatus(status);
    _items[_items.indexOf(request)] = updatedRequest;
    call
      ..request = updatedRequest
      ..answer = answer;
  }

  void _invalidatePendingApprovals() {
    final pending = _calls.where((call) => call.pending).toList();
    if (pending.isNotEmpty) {
      for (final call in pending) {
        _decide(call, .invalidated, _invalidated);
      }
      notifyListeners();
    }
  }

  String _context() => jsonEncode(AgentListing.of(_surface).context);

  bool get _canFollowUp =>
      _calls.isNotEmpty &&
      !_stopping &&
      _calls.every((call) => call.answer != null);

  void _handleConnectionLost(_Run run) {
    if (run.ended) {
      return;
    }
    _items.add(const ChatNotice(.connectionLost));
    // What ADK kept of the run is unknown, so the chat moves to a new thread.
    _threadId = const Uuid().v4();
    _history.clear();
    _completeOperation();
  }

  void _completeOperation({bool followUp = false}) {
    _run = null;
    _stopping = false;
    if (_queuedMessages.isNotEmpty) {
      _start(_queuedMessages.removeAt(0));
    } else if (followUp) {
      _start();
    }
    notifyListeners();
  }
}

final class _Run(final AgentListing listing) {
  final messageText = <String, String>{};
  final textItemIndices = <String, int>{};
  final calls = <String, _Call>{};
  bool ended = false;

  List<Map<String, Object?>> get assistantMessages => [
    for (final MapEntry(:key, :value) in messageText.entries)
      assistantText(key, value),
  ];

  ({String messageId, String text})? read(
    AgentEvent event, {
    required bool showText,
  }) {
    switch (event) {
      case TextDelta(:final messageId, :final delta) when showText:
        final text = (messageText[messageId] ?? '') + delta;
        messageText[messageId] = text;
        return (messageId: messageId, text: text);
      // A call of a tool the listing does not list runs on the server.
      case ToolCallStarted(:final toolCallId, :final name)
          when listing.lists(name):
        calls[toolCallId] = _Call(toolCallId, name);
      case ToolCallArgs(:final toolCallId, :final delta):
        calls[toolCallId]?.arguments += delta;
      case _:
    }
    return null;
  }
}

final class _Call(final String id, final String tool) {
  String arguments = '';
  String? answer;
  ApprovalRequest? request;

  bool get pending => request?.status == .pending;
  bool get approved => request?.status == .approved;

  // ag-ui-adk sends no `TOOL_CALL_ARGS` for a call without arguments.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;

  bool get hasObjectArguments {
    try {
      return jsonDecode(argumentsJson) is Map<String, Object?>;
    } on FormatException {
      return false;
    }
  }
}
