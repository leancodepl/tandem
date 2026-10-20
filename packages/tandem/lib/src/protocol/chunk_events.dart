import 'package:tandem/src/protocol/ag_ui.dart';

/// Expands text and tool-call chunks, tracking open streams per sender.
/// Create one per run. Ambiguous chunks throw [FormatException].
/// Chunk ownership and closing rules: doc/design.md#wire-rules.
final class ChunkExpander() {
  static const _senderClosingEvents = {
    AgUiEventTypes.textMessageStart,
    AgUiEventTypes.textMessageContent,
    AgUiEventTypes.textMessageEnd,
    AgUiEventTypes.toolCallStart,
    AgUiEventTypes.toolCallArgs,
    AgUiEventTypes.toolCallEnd,
    AgUiEventTypes.toolCallResult,
    AgUiEventTypes.stateSnapshot,
    AgUiEventTypes.stateDelta,
    AgUiEventTypes.stepStarted,
    AgUiEventTypes.stepFinished,
    AgUiEventTypes.reasoningStart,
    AgUiEventTypes.reasoningMessageStart,
    AgUiEventTypes.reasoningMessageContent,
    AgUiEventTypes.reasoningMessageEnd,
    AgUiEventTypes.reasoningEnd,
    AgUiEventTypes.custom,
  };

  // Keyed by sender: its `subagentRunId`, or null for the parent.
  final _openBySender = <String?, ({_Kind kind, String id})>{};

  Iterable<JsonObject> call(JsonObject event) {
    switch (event[AgUiFields.type]) {
      case AgUiEventTypes.textMessageChunk:
        return _expandText(event);
      case AgUiEventTypes.toolCallChunk:
        return _expandToolCall(event);
      case AgUiEventTypes.reasoningMessageChunk:
        _trackReasoningChunk(event);
      case final type when _senderClosingEvents.contains(type):
        _openBySender.remove(_senderOf(event));
      case AgUiEventTypes.subagentFinished || AgUiEventTypes.subagentError:
        _closeSubagentStream(event);
      case AgUiEventTypes.runStarted ||
          AgUiEventTypes.runFinished ||
          AgUiEventTypes.runError ||
          AgUiEventTypes.messagesSnapshot:
        _openBySender.clear();
    }
    return [event];
  }

  List<JsonObject> _expandText(JsonObject chunk) {
    final messageId = _resolveId(
      chunk,
      kind: .text,
      id: chunk[AgUiFields.messageId],
    );
    if (messageId == null) {
      return [];
    }

    if (_isNewStream(.text, messageId)) {
      _openBySender[_senderOf(chunk)] = (kind: .text, id: messageId);
    }
    return [
      if (chunk[AgUiFields.delta] case final String delta)
        {
          AgUiFields.type: AgUiEventTypes.textMessageContent,
          AgUiFields.messageId: messageId,
          AgUiFields.delta: delta,
        },
    ];
  }

  List<JsonObject> _expandToolCall(JsonObject chunk) {
    final toolCallId = _resolveId(
      chunk,
      kind: .toolCall,
      id: chunk[AgUiFields.toolCallId],
    );
    if (toolCallId == null) {
      return [];
    }

    final events = <JsonObject>[];
    if (_isNewStream(.toolCall, toolCallId)) {
      final name = chunk[AgUiFields.toolCallName];
      if (name is! String) {
        return [];
      }
      _openBySender[_senderOf(chunk)] = (kind: .toolCall, id: toolCallId);
      events.add({
        AgUiFields.type: AgUiEventTypes.toolCallStart,
        AgUiFields.toolCallId: toolCallId,
        AgUiFields.toolCallName: name,
      });
    }
    if (chunk[AgUiFields.delta] case final String delta) {
      events.add({
        AgUiFields.type: AgUiEventTypes.toolCallArgs,
        AgUiFields.toolCallId: toolCallId,
        AgUiFields.delta: delta,
      });
    }
    return events;
  }

  void _trackReasoningChunk(JsonObject chunk) {
    final messageId = chunk[AgUiFields.messageId];
    if (messageId is! String) {
      return;
    }

    if (_isNewStream(.reasoning, messageId)) {
      _openBySender[_senderOf(chunk)] = (kind: .reasoning, id: messageId);
    }
  }

  void _closeSubagentStream(JsonObject event) {
    final sender = _senderOf(event);
    if (sender == null) {
      return;
    }

    _openBySender.remove(sender);
  }

  bool _isNewStream(_Kind kind, String id) =>
      _openBySender.values.every((open) => open != (kind: kind, id: id));

  String? _resolveId(
    JsonObject chunk, {
    required _Kind kind,
    required Object? id,
  }) {
    if (id is String) {
      return id;
    }

    final sender = _senderOf(chunk);
    if (_openBySender[sender] case final open? when open.kind == kind) {
      return open.id;
    }
    if (sender != null) {
      return null;
    }

    final candidates = [
      for (final open in _openBySender.values)
        if (open.kind == kind) open.id,
    ];
    return switch (candidates) {
      [] => null,
      [final id] => id,
      _ => throw _ambiguous(chunk),
    };
  }
}

enum _Kind() {
  text,
  toolCall,
  reasoning,
}

String? _senderOf(JsonObject event) =>
    switch (event[AgUiFields.subagentRunId]) {
      final String sender => sender,
      _ => null,
    };

FormatException _ambiguous(JsonObject chunk) => FormatException(
  '${chunk[AgUiFields.type]} without an id could continue the stream of several '
  'subagents',
);
