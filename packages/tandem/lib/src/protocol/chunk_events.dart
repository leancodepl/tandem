/// Rewrites the chunk events of one run as the events they abbreviate, so the
/// session reads a run the same way whichever form the agent uses.
///
/// `TEXT_MESSAGE_CHUNK` becomes `TEXT_MESSAGE_CONTENT`. `TOOL_CALL_CHUNK`
/// becomes `TOOL_CALL_START`, when it opens a call, and `TOOL_CALL_ARGS`. As in
/// AG-UI, a chunk with an id other than the last one starts a new message or
/// call, and a chunk without an id continues the last one. A chunk that
/// belongs to nothing, or opens a call without its name, is dropped. Every
/// other event passes through.
final class ChunkExpander() {
  /// Starts a run with no message or call open. Each run needs its own
  /// expander, which remembers the ids of the run's last message and call.
  this;

  String? _messageId;
  String? _toolCallId;

  /// The events that [event] stands for.
  Iterable<Map<String, Object?>> call(Map<String, Object?> event) =>
      switch (event) {
        {'type': 'TEXT_MESSAGE_CHUNK'} => _text(event),
        {'type': 'TOOL_CALL_CHUNK'} => _toolCall(event),
        _ => [event],
      };

  Iterable<Map<String, Object?>> _text(Map<String, Object?> chunk) sync* {
    final messageId = _idOr(chunk['messageId'], _messageId);
    _messageId = messageId;
    if (chunk['delta'] case final String delta when messageId != null) {
      yield {
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': messageId,
        'delta': delta,
      };
    }
  }

  Iterable<Map<String, Object?>> _toolCall(Map<String, Object?> chunk) sync* {
    final toolCallId = _idOr(chunk['toolCallId'], _toolCallId);
    if (toolCallId == null) {
      return;
    }
    if (toolCallId != _toolCallId) {
      if (chunk['toolCallName'] case final String name) {
        _toolCallId = toolCallId;
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
  }
}

/// [id] when it is a string, else [last].
String? _idOr(Object? id, String? last) => id is String ? id : last;
