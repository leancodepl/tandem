import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/ag_ui_ids.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/view_tool.dart';

/// What the session keeps of its open run.
final class Run(
  final AgentListing listing, {
  required final List<ChatItem> _chat,

  /// The view the run offers the agent to draw on.
  final OfferedView? view,
}) {
  ChatEntry<AgentMessage>? _lastText;

  /// The body the connection got, which a Stop sends back to it.
  late final JsonObject input;

  bool get stopped => _stopped;
  var _stopped = false;

  /// Whether the connection was told to stop the run on its server and did
  /// not fail, so a `RUN_ERROR` may be the server's answer.
  bool get toldToStop => _toldToStop;
  var _toldToStop = false;

  /// Whether what the agent sees differed from what this run sent, at any
  /// check since it started, even when it changed back.
  bool get seesChanged => _seesChanged;
  var _seesChanged = false;
  late final _seen = SeesSnapshot.of(listing);

  void compareScreen(SeesSnapshot now) {
    if (now != _seen) _seesChanged = true;
  }

  /// The listed method that runs now.
  Calling? calling;

  /// Set by `RUN_FINISHED` and `RUN_ERROR`, so the end of the stream that
  /// follows does not count as a lost connection.
  bool ended = false;

  /// The agent's messages in the order they started, with their calls.
  final _messages = <MessageId, _StreamedMessage>{};
  final _calls = <ToolCallId, _StreamedCall>{};

  /// The latest call of a tool that is not a listed method, until
  /// the agent's next text or call, or its result.
  _StreamedCall? _used;

  /// Tells the server of [connection] to stop this run, if the connection
  /// can and the server has not ended the run yet. Reports the error of a
  /// connection that fails to.
  Future<void> stopOnServer(AgentConnection connection) async {
    if (ended || connection is! StoppableAgentConnection) {
      return;
    }
    _toldToStop = true;
    try {
      await connection.stop(input);
    } catch (err, st) {
      _toldToStop = false;
      report(err, st);
    }
  }

  /// Marks the last text as stopped, or adds a notice before the first text.
  void stop() {
    _stopped = true;
    if (_lastText case final last?) {
      last.value = AgentMessage(last.value.text, stopped: true);
    } else {
      _chat.add(const ChatNotice(.stopped));
    }
  }

  List<JsonObject> get tools => [...listing.tools, ?view?.definition];

  SessionStatus get status {
    if (stopped) return const Stopping();
    if (calling case final method?) return method;
    return switch (_used) {
      _StreamedCall(inApp: false, :final tool) => Thinking(backendTool: tool),
      _StreamedCall(tool: ViewTool.name) => const Thinking(drawing: true),
      _ => const Thinking(),
    };
  }

  /// Records streamed output. Returns whether the session should notify its
  /// listeners: argument fragments are buffered until the call is complete.
  bool receive(RunOutput output) {
    switch (output) {
      case TextStarted(:final messageId, :final metadata) ||
          TextEnded(:final messageId, :final metadata):
        _message(MessageId.wire(messageId)).metadata.addAll(metadata);
        return false;
      case TextDelta(:final messageId, :final delta, :final metadata):
        final message = _message(MessageId.wire(messageId));
        message.metadata.addAll(metadata);
        if (stopped || delta.isEmpty) return false;
        _write(message, delta);
      case final ToolCallStarted start:
        _startTool(start);
      case ToolCallArgs(:final toolCallId, :final delta, :final metadata):
        if (_calls[ToolCallId.wire(toolCallId)] case final call?) {
          call.arguments += delta;
          call.metadata.addAll(metadata);
        }
        return false;
      case ToolCallEnded(:final toolCallId, :final metadata):
        _calls[ToolCallId.wire(toolCallId)]?.metadata.addAll(metadata);
        return false;
      case final ToolCallResult result:
        final call = _calls[ToolCallId.wire(result.toolCallId)];
        if (identical(_used, call)) _used = null;
        if (call case _StreamedCall(inApp: false)) call.result = result;
    }
    return true;
  }

  _StreamedMessage _message(MessageId id) =>
      _messages.putIfAbsent(id, _StreamedMessage.new);

  void _write(_StreamedMessage message, String delta) {
    _used = null;
    final shown = message.shown;
    if (shown != null) {
      shown.value = AgentMessage('${shown.value.text}$delta');
      return;
    }
    final entry = ChatEntry(_chat, AgentMessage(delta));
    message.shown = entry;
    _lastText = entry;
  }

  /// Records the first start of a call with its parent message. A repeated
  /// start must name the same tool.
  void _startTool(ToolCallStarted start) {
    final ToolCallStarted(name: tool, :parentMessageId) = start;
    final id = ToolCallId.wire(start.toolCallId);
    final existing = _calls[id];
    if (existing != null) {
      if (existing.tool != tool) {
        throw const FormatException('A tool call changed its method.');
      }
      existing.metadata.addAll(start.metadata);
      return;
    }

    final listed = listing.lists(tool);
    final call = _StreamedCall(
      id,
      tool,
      inApp: listed || (tool == ViewTool.name && view != null),
    )..metadata.addAll(start.metadata);
    _calls[id] = call;
    _used = listed ? null : call;
    final messageId = switch (parentMessageId) {
      final id? => MessageId.wire(id),
      // Never reuse a message id: ag-ui-adk would swallow its answer.
      null => MessageId.local(),
    };
    _message(messageId).calls.add(call);
  }

  /// The calls that run in the app, once the run finished streaming.
  List<ToolCall> collectAppCalls() => [
    for (final call in _calls.values)
      if (call.inApp)
        ToolCall(
          id: call.id,
          tool: call.tool,
          description: listing.toolNamed(call.tool)?.description ?? '',
          caller: .inAppAgent,
          argumentsJson: call.argumentsJson,
        ),
  ];

  /// On failure the backend has seen the text but has no answers to its calls.
  Iterable<AgUiMessage> get textHistory sync* {
    for (final MapEntry(key: id, value: message) in _messages.entries) {
      if (message.shown case final shown?) {
        yield AgUiMessage.assistant(
          id,
          text: shown.value.text,
          metadata: message.metadata,
        );
      }
    }
  }

  /// The messages of the run, each followed by its backend results. A
  /// backend call without a result stays out. An app-id thread also keeps
  /// the messages with app calls until their answers go out.
  Iterable<({List<AgUiMessage> messages, bool hasAppCalls})> get history sync* {
    for (final MapEntry(key: id, value: message) in _messages.entries) {
      final calls = [
        for (final call in message.calls)
          if (call.inApp || call.result != null) call,
      ];
      final text = message.shown?.value.text;
      if (text == null && calls.isEmpty) continue;
      final messages = <AgUiMessage>[
        .assistant(
          id,
          text: text,
          metadata: message.metadata,
          toolCalls: [for (final call in calls) call.wire],
        ),
        for (final call in calls)
          if (call.result case final result?)
            .toolResult(
              id: .wire(result.messageId),
              toolCallId: call.id,
              content: result.content,
              metadata: result.metadata,
            ),
      ];
      yield (messages: messages, hasAppCalls: calls.any((call) => call.inApp));
    }
  }
}

final class _StreamedMessage() {
  ChatEntry<AgentMessage>? shown;
  final metadata = <String, Object?>{};
  final calls = <_StreamedCall>[];
}

final class _StreamedCall(
  final ToolCallId id,
  final String tool, {
  required final bool inApp,
}) {
  String arguments = '';
  final metadata = <String, Object?>{};
  ToolCallResult? result;

  // A call without arguments has no `TOOL_CALL_ARGS`.
  String get argumentsJson => arguments.isEmpty ? '{}' : arguments;

  AgUiToolCall get wire =>
      .new(id: id, name: tool, arguments: argumentsJson, metadata: metadata);
}
