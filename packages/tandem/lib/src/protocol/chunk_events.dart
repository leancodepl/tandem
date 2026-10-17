/// Rewrites the chunk events of one run as the events they abbreviate, so the
/// session reads a run the same way whichever form the agent uses.
///
/// `TEXT_MESSAGE_CHUNK` becomes `TEXT_MESSAGE_CONTENT`. `TOOL_CALL_CHUNK`
/// becomes `TOOL_CALL_START`, when it opens a call, and `TOOL_CALL_ARGS`.
/// `REASONING_MESSAGE_CHUNK` passes through, as the session shows no
/// reasoning, and so does every other event.
///
/// As in AG-UI, a chunk with an id no open stream has opens a new message,
/// call or reasoning message, and a chunk without an id continues the open
/// one of its sender: the subagent its `subagentRunId` names, or the parent.
/// Subagents can interleave their chunks, so each sender has its own open
/// stream, and opening one closes the one it had. The sender's other text,
/// call, state, step, reasoning and custom events close it too.
/// `SUBAGENT_FINISHED` and `SUBAGENT_ERROR` close the one of their subagent,
/// and a run event or `MESSAGES_SNAPSHOT` closes them all.
///
/// A chunk with neither id nor `subagentRunId` continues the parent's open
/// message or call, else the only one open in any subagent. When several
/// subagents have one open and the parent has none, it is refused with a
/// [FormatException], like malformed JSON, so the run counts as broken. A
/// chunk that belongs to nothing, or opens a call without a name, is dropped.
final class ChunkExpander() {
  /// An expander for one run. Each run needs its own, as it remembers the
  /// open streams.
  this;

  // Keyed by sender: its `subagentRunId`, or null for the parent.
  final _streams = <String?, ({_Kind kind, String id})>{};

  /// The events that [event] stands for.
  Iterable<Map<String, Object?>> call(Map<String, Object?> event) {
    switch (event['type']) {
      case 'TEXT_MESSAGE_CHUNK':
        return _text(event);
      case 'TOOL_CALL_CHUNK':
        return _toolCall(event);
      case 'REASONING_MESSAGE_CHUNK':
        if (event['messageId'] case final String messageId
            when !_isOpen(.reasoning, messageId)) {
          _streams[_senderOf(event)] = (kind: .reasoning, id: messageId);
        }
      case 'TEXT_MESSAGE_START' ||
          'TEXT_MESSAGE_CONTENT' ||
          'TEXT_MESSAGE_END' ||
          'TOOL_CALL_START' ||
          'TOOL_CALL_ARGS' ||
          'TOOL_CALL_END' ||
          'TOOL_CALL_RESULT' ||
          'STATE_SNAPSHOT' ||
          'STATE_DELTA' ||
          'STEP_STARTED' ||
          'STEP_FINISHED' ||
          'REASONING_START' ||
          'REASONING_MESSAGE_START' ||
          'REASONING_MESSAGE_CONTENT' ||
          'REASONING_MESSAGE_END' ||
          'REASONING_END' ||
          'CUSTOM':
        _streams.remove(_senderOf(event));
      case 'SUBAGENT_FINISHED' || 'SUBAGENT_ERROR':
        // Without a subagent the event is malformed, and closes nothing.
        if (event['subagentRunId'] case final String sender) {
          _streams.remove(sender);
        }
      case 'RUN_STARTED' ||
          'RUN_FINISHED' ||
          'RUN_ERROR' ||
          'MESSAGES_SNAPSHOT':
        _streams.clear();
    }
    return [event];
  }

  Iterable<Map<String, Object?>> _text(Map<String, Object?> chunk) sync* {
    final sender = _senderOf(chunk);
    switch (_candidates(.text, chunk['messageId'], sender)) {
      case []:
        return;
      case [final messageId]:
        if (!_isOpen(.text, messageId)) {
          _streams[sender] = (kind: .text, id: messageId);
        }
        if (chunk['delta'] case final String delta) {
          yield {
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': messageId,
            'delta': delta,
          };
        }
      case _:
        throw _ambiguous(chunk);
    }
  }

  Iterable<Map<String, Object?>> _toolCall(Map<String, Object?> chunk) sync* {
    final sender = _senderOf(chunk);
    switch (_candidates(.toolCall, chunk['toolCallId'], sender)) {
      case []:
        return;
      case [final toolCallId]:
        if (!_isOpen(.toolCall, toolCallId)) {
          if (chunk['toolCallName'] case final String name) {
            _streams[sender] = (kind: .toolCall, id: toolCallId);
            yield {
              'type': 'TOOL_CALL_START',
              'toolCallId': toolCallId,
              'toolCallName': name,
            };
          } else {
            return;
          }
        }
        if (chunk['delta'] case final String delta) {
          yield {
            'type': 'TOOL_CALL_ARGS',
            'toolCallId': toolCallId,
            'delta': delta,
          };
        }
      case _:
        throw _ambiguous(chunk);
    }
  }

  bool _isOpen(_Kind kind, String id) =>
      _streams.containsValue((kind: kind, id: id));

  List<String> _candidates(_Kind kind, Object? id, String? sender) {
    if (id is String) {
      return [id];
    }
    if (_streams[sender] case final open? when open.kind == kind) {
      return [open.id];
    }
    return [
      if (sender == null)
        for (final open in _streams.values)
          if (open.kind == kind) open.id,
    ];
  }
}

enum _Kind() {
  text,
  toolCall,
  reasoning,
}

String? _senderOf(Map<String, Object?> event) =>
    switch (event['subagentRunId']) {
      final String sender => sender,
      _ => null,
    };

FormatException _ambiguous(Map<String, Object?> chunk) => FormatException(
  '${chunk['type']} without an id could continue the stream of several '
  'subagents',
);
