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
        return _expand(event, .text);
      case AgUiEventTypes.toolCallChunk:
        return _expand(event, .toolCall);
      case AgUiEventTypes.reasoningMessageChunk:
        if (event[AgUiFields.messageId] case final String id) {
          final stream = (kind: _Kind.reasoning, id: id);
          if (!_openBySender.containsValue(stream)) {
            _openBySender[_senderOf(event)] = stream;
          }
        }
      case final type when _senderClosingEvents.contains(type):
        _openBySender.remove(_senderOf(event));
      case AgUiEventTypes.subagentFinished || AgUiEventTypes.subagentError:
        if (_senderOf(event) case final sender?) _openBySender.remove(sender);
      case AgUiEventTypes.runStarted ||
          AgUiEventTypes.runFinished ||
          AgUiEventTypes.runError ||
          AgUiEventTypes.messagesSnapshot:
        _openBySender.clear();
    }
    return [event];
  }

  List<JsonObject> _expand(JsonObject chunk, _Kind kind) {
    final isTool = kind == _Kind.toolCall;
    final idField = isTool ? AgUiFields.toolCallId : AgUiFields.messageId;
    final id = _resolveId(chunk, kind: kind, id: chunk[idField]);
    if (id == null) return [];

    final delta = chunk[AgUiFields.delta];
    final hasMetadata = chunk.containsKey(AgUiFields.metadata);
    final stream = (kind: kind, id: id);
    final events = <JsonObject>[];
    if (!_openBySender.containsValue(stream)) {
      if (isTool) {
        final name = chunk[AgUiFields.toolCallName];
        if (name is! String) return [];
        events.add({
          AgUiFields.type: AgUiEventTypes.toolCallStart,
          AgUiFields.toolCallId: id,
          AgUiFields.toolCallName: name,
          if (chunk[AgUiFields.parentMessageId] case final String parentId)
            AgUiFields.parentMessageId: parentId,
          if (hasMetadata) AgUiFields.metadata: chunk[AgUiFields.metadata],
        });
      } else if (delta == null) {
        events.add({
          AgUiFields.type: AgUiEventTypes.textMessageStart,
          AgUiFields.messageId: id,
          AgUiFields.role: chunk[AgUiFields.role] ?? AgUiMessageRoles.assistant,
          if (hasMetadata) AgUiFields.metadata: chunk[AgUiFields.metadata],
        });
      }
      _openBySender[_senderOf(chunk)] = stream;
    }
    if (delta is String || (hasMetadata && events.isEmpty)) {
      events.add({
        AgUiFields.type: isTool
            ? AgUiEventTypes.toolCallArgs
            : AgUiEventTypes.textMessageContent,
        idField: id,
        AgUiFields.delta: delta is String ? delta : '',
        if (hasMetadata) AgUiFields.metadata: chunk[AgUiFields.metadata],
      });
    }
    return events;
  }

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
