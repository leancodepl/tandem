// Internal: not exported. The rules a ScriptedAgent with checkProtocol checks
// every request against.

import 'dart:convert';

import 'package:tandem/src/protocol/json_patch/json_value.dart';
import 'package:tandem/src/protocol/wire/events.dart';
import 'package:tandem/src/protocol/wire/messages.dart';
import 'package:tandem/src/protocol/wire/run_input.dart';
import 'package:tandem/src/protocol/wire/wire_conventions.dart';

/// The AG-UI rules Tandem keeps (doc/design.md, "Runs and history"), plus the
/// ag-ui-adk pitfalls that silently drop approvals, checked request by
/// request for one session.
///
/// It remembers what earlier requests sent and which events the app received
/// in the last accepted run, so it can tell whether the next request carries
/// the whole history.
final class ProtocolRules {
  String? _threadId;
  final _runIds = <String>{};
  final _agentToolCallIds = <String>{};
  _History? _history;

  /// Every rule [input] breaks, one sentence each; empty when it keeps them
  /// all. [busyRunId] is the id of a run that is still streaming, if any.
  List<String> check(RunInput input, {String? busyRunId}) => [
    ..._checkRequest(input, busyRunId),
    ..._checkState(input),
    ..._checkMessageIds(input),
    ..._checkAnswers(input),
    ...?_history?.check(input),
  ];

  /// Remembers the thread and run id of [input]. Called for every request,
  /// accepted or not.
  void sawRequest(RunInput input) {
    _threadId ??= input.threadId;
    _runIds.add(input.runId);
  }

  /// Starts remembering what the app receives in the run for [input], which
  /// the agent accepted.
  void accepted(RunInput input) => _history = _History(input);

  /// Remembers one event the app received in the accepted run.
  void delivered(WireEvent event) {
    switch (event) {
      case ToolCallStart(:final toolCallId):
        _agentToolCallIds.add(toolCallId);
      case ToolCallChunk(:final String toolCallId):
        _agentToolCallIds.add(toolCallId);
      default:
        break;
    }
    _history?.add(event);
  }

  Iterable<String> _checkRequest(RunInput input, String? busyRunId) sync* {
    if (input.toJson()['tools'] is! List<Object?>) {
      yield 'The request has no "tools". ag-ui-adk fails the run without it; '
          'send [] when the app has no tools.';
    }
    if (input.threadId.isEmpty) {
      yield 'The thread id is empty.';
    }
    final threadId = _threadId;
    if (threadId != null && input.threadId != threadId) {
      yield 'The thread id is "${input.threadId}", but the session\'s first '
          'run used "$threadId". Every run of a session uses the same thread '
          'id; another id starts a new conversation on the backend, which '
          'then forgets the open tool calls.';
    }
    if (input.runId.isEmpty) {
      yield 'The run id is empty.';
    } else if (_runIds.contains(input.runId)) {
      yield 'The run id "${input.runId}" was already used. Every run needs a '
          'new run id.';
    }
    if (busyRunId != null) {
      yield 'Run "${input.runId}" started while run "$busyRunId" was still '
          'streaming. Only one run may be in progress at a time.';
    }
  }

  Iterable<String> _checkState(RunInput input) sync* {
    for (final key in input.state.keys.where(WireConventions.isServerKey)) {
      if (key == WireConventions.pendingToolCallsKey) {
        yield 'The state contains "$key", which the agent backend owns. '
            "Echoing it wipes ag-ui-adk's list of open tool calls, and later "
            "answers to them are dropped. Send only the app's own keys.";
      } else {
        yield 'The state contains "$key", which the agent backend owns. Send '
            "only the app's own keys.";
      }
    }
  }

  Iterable<String> _checkMessageIds(RunInput input) sync* {
    final toolCallIds = {
      ..._agentToolCallIds,
      for (final message in input.messages)
        if (message is WireAssistantMessage)
          for (final call in message.toolCalls) call.id,
    };
    final seen = <String>{};
    for (final message in input.messages) {
      final id = message.id;
      if (id.isEmpty) {
        yield 'A ${_role(message)} message has an empty id.';
        continue;
      }
      if (!seen.add(id)) {
        yield 'The message id "$id" is used twice in the history.';
      }
      if (toolCallIds.contains(id)) {
        yield 'The ${_role(message)} message "$id" has the id of a tool call. '
            'ag-ui-adk marks message ids as processed and then drops the late '
            'answer to that call; give the message its own id, such as '
            '"${WireConventions.assistantMessagePrefix}$id".';
      }
    }
  }

  Iterable<String> _checkAnswers(RunInput input) sync* {
    final declared = {for (final tool in input.tools) tool.name};
    final calls = <String, _SentCall>{};
    final answers = <String, List<int>>{};
    final messages = input.messages;
    for (var index = 0; index < messages.length; index++) {
      switch (messages[index]) {
        case WireAssistantMessage(:final toolCalls):
          for (final call in toolCalls) {
            if (calls.containsKey(call.id)) {
              yield 'The tool call "${call.id}" appears in two assistant '
                  'messages.';
            } else {
              calls[call.id] = (name: call.name, index: index);
            }
          }
        case WireToolMessage(:final id, :final toolCallId):
          if (calls.containsKey(toolCallId)) {
            (answers[toolCallId] ??= []).add(index);
          } else {
            yield 'The tool message "$id" answers "$toolCallId", but no '
                'earlier assistant message contains that call. ag-ui-adk then '
                'gives the answer to the model under the name "unknown".';
          }
        case WireUserMessage():
          break;
      }
    }
    for (final MapEntry(key: id, value: call) in calls.entries) {
      if (!declared.contains(call.name)) {
        // An agent tool: the agent answers it itself, if at all.
        continue;
      }
      final described = 'Tool call "$id" (${call.name})';
      final answeredAt = answers[id] ?? const [];
      if (answeredAt.isEmpty) {
        yield "$described is not answered. Every call of the app's tools is "
            'answered before or together with the next user message.';
        continue;
      }
      if (answeredAt.length > 1) {
        final ids = answeredAt.map((index) => '"${messages[index].id}"');
        yield '$described is answered ${answeredAt.length} times, by '
            '${ids.join(', ')}.';
      }
      final nextUser = _nextUserMessage(messages, after: call.index);
      if (nextUser != null && answeredAt.first > nextUser) {
        yield '$described is answered only after the user message '
            '"${messages[nextUser].id}". Tool answers come before the next '
            'user message; ag-ui-adk would otherwise drop the chat in between '
            "from the model's context.";
      }
    }
  }

  static int? _nextUserMessage(
    List<WireMessage> messages, {
    required int after,
  }) {
    for (var index = after + 1; index < messages.length; index++) {
      if (messages[index] is WireUserMessage) {
        return index;
      }
    }
    return null;
  }
}

/// A tool call as the history sends it: its name and the position of its
/// assistant message.
typedef _SentCall = ({String name, int index});

/// What the next request must contain: the history the last accepted request
/// sent, plus everything the app received in that run.
final class _History {
  _History(RunInput input) : _base = [for (final m in input.messages) m.id];

  /// The ids of the history the run started from, in order. A
  /// `MESSAGES_SNAPSHOT` replaces it.
  List<String> _base;

  final _openTexts = <String, StringBuffer>{};
  final _texts = <({String id, String text})>[];
  final _calls = <String, _ReceivedCall>{};
  final _results = <({String messageId, String toolCallId})>[];

  void add(WireEvent event) {
    switch (event) {
      case MessagesSnapshot(:final messages):
        _base = [for (final message in messages) message.id];
        _texts.clear();
        _results.clear();
        _calls.removeWhere((_, call) => call.isComplete);
      case TextStart(:final messageId):
        _openTexts[messageId] = StringBuffer();
      case TextContent(:final messageId, :final delta):
        _openTexts[messageId]?.write(delta);
      case TextEnd(:final messageId):
        final text = _openTexts.remove(messageId);
        if (text != null) {
          _texts.add((id: messageId, text: text.toString()));
        }
      case ToolCallStart(:final toolCallId, :final toolCallName):
        _calls[toolCallId] = _ReceivedCall(
          toolCallName,
          parentMessageId: event.parentMessageId,
        );
      case ToolCallArgs(:final toolCallId, :final delta):
        _calls[toolCallId]?.arguments.write(delta);
      case ToolCallEnd(:final toolCallId):
        _calls[toolCallId]?.isComplete = true;
      case ToolCallResult(:final messageId, :final toolCallId):
        _results.add((messageId: messageId, toolCallId: toolCallId));
      default:
        // Run, state and chunk events add nothing the history must contain.
        break;
    }
  }

  Iterable<String> check(RunInput input) sync* {
    final byId = <String, WireMessage>{};
    final positions = <String, int>{};
    for (var index = 0; index < input.messages.length; index++) {
      final message = input.messages[index];
      byId.putIfAbsent(message.id, () => message);
      positions.putIfAbsent(message.id, () => index);
    }
    final completeCalls = {
      for (final MapEntry(:key, :value) in _calls.entries)
        if (value.isComplete) key: value,
    };
    final expected = {
      ..._base,
      for (final text in _texts) text.id,
      for (final call in completeCalls.values) ?call.parentMessageId,
      for (final result in _results) result.messageId,
    };
    final missing = expected.where((id) => !byId.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final ids = missing.map((id) => '"$id"').join(', ');
      yield 'The history lacks ${missing.length == 1 ? 'message' : 'messages'} '
          '$ids of earlier runs. Every run sends the whole history.';
    }
    yield* _checkOrder(positions);
    for (final (:id, :text) in _texts) {
      switch (byId[id]) {
        case null:
          break;
        case WireAssistantMessage(:final content) when (content ?? '') != text:
          yield 'The assistant message "$id" has the text '
              '${jsonEncode(content)} in the history, but the agent said '
              '${jsonEncode(text)}.';
        case WireAssistantMessage():
          break;
        case final message:
          yield 'The agent\'s text message "$id" is sent back as a '
              '${_role(message)} message.';
      }
    }
    for (final MapEntry(key: id, value: call) in completeCalls.entries) {
      yield* _checkCall(id, call, input, missing);
    }
    for (final (:messageId, :toolCallId) in _results) {
      switch (byId[messageId]) {
        case null:
          break;
        case WireToolMessage(toolCallId: final answered)
            when answered != toolCallId:
          yield 'The tool message "$messageId" answers "$answered", but the '
              'agent sent it as the result of "$toolCallId".';
        case WireToolMessage():
          break;
        case final message:
          yield 'The result "$messageId" of the agent tool call "$toolCallId" '
              'is sent back as a ${_role(message)} message, not as a tool '
              'message.';
      }
    }
  }

  Iterable<String> _checkOrder(Map<String, int> positions) sync* {
    String? previousId;
    var previousPosition = -1;
    for (final id in _base) {
      final position = positions[id];
      if (position == null) {
        continue;
      }
      if (position < previousPosition) {
        yield 'The history changed the order of earlier messages: "$id" now '
            'comes before "$previousId".';
        return;
      }
      previousId = id;
      previousPosition = position;
    }
  }

  Iterable<String> _checkCall(
    String id,
    _ReceivedCall call,
    RunInput input,
    List<String> missing,
  ) sync* {
    final parentId = call.parentMessageId;
    if (parentId != null && missing.contains(parentId)) {
      return;
    }
    WireAssistantMessage? host;
    WireToolCall? sent;
    for (final message in input.messages.whereType<WireAssistantMessage>()) {
      for (final candidate in message.toolCalls) {
        if (candidate.id == id) {
          host = message;
          sent = candidate;
        }
      }
    }
    if (host == null || sent == null) {
      yield 'The history lacks the agent\'s tool call "$id" (${call.name}). '
          'Every completed tool call goes into an assistant message.';
      return;
    }
    if (parentId != null && host.id != parentId) {
      yield 'The tool call "$id" belongs to the assistant message "$parentId" '
          '(its parentMessageId), but the history puts it into "${host.id}".';
    }
    if (sent.name != call.name) {
      yield 'The tool call "$id" is named "${sent.name}" in the history, but '
          'the agent called "${call.name}".';
    }
    final received = call.arguments.toString();
    final receivedJson = _decodeOrInvalid(received.isEmpty ? '{}' : received);
    if (!identical(receivedJson, _invalid) &&
        !jsonEquals(_decodeOrInvalid(sent.arguments), receivedJson)) {
      yield 'The tool call "$id" has the arguments ${sent.arguments} in the '
          'history, but the agent sent ${received.isEmpty ? '{}' : received}.';
    }
  }

  static const Object _invalid = Object();

  static Object? _decodeOrInvalid(String json) {
    try {
      return jsonDecode(json);
    } on FormatException {
      return _invalid;
    }
  }
}

/// A tool call the app received in the last accepted run.
final class _ReceivedCall {
  _ReceivedCall(this.name, {required this.parentMessageId});

  final String name;
  final String? parentMessageId;
  final arguments = StringBuffer();
  bool isComplete = false;
}

String _role(WireMessage message) => switch (message) {
  WireUserMessage() => 'user',
  WireAssistantMessage() => 'assistant',
  WireToolMessage() => 'tool',
};
