const _ambiguousChunkCode = 'AMBIGUOUS_CHUNK';

/// Rewrites the chunk events of one run as the events they abbreviate, so the
/// session reads a run the same way whichever form the agent uses.
///
/// `TEXT_MESSAGE_CHUNK` becomes `TEXT_MESSAGE_CONTENT`. `TOOL_CALL_CHUNK`
/// becomes `TOOL_CALL_START`, when it opens a call, and `TOOL_CALL_ARGS`. As in
/// AG-UI, a chunk with an id no open stream has opens a new message or call,
/// and a chunk without an id continues the open one of its sender: the
/// subagent its `subagentRunId` names, or the parent when it has none.
/// Subagents can interleave their chunks, so each sender has its own open
/// stream, a message or a call, and opening one closes the one it had.
///
/// A chunk with neither id nor `subagentRunId` continues the parent's open
/// message or call, else the only one open in any subagent. When several
/// subagents have one open and the parent has none, it could join any of
/// them: it is refused, and the run ends with a `RUN_ERROR` whose code is
/// `AMBIGUOUS_CHUNK`. A chunk that belongs to nothing, or opens a call
/// without its name, is dropped. Every other event passes through.
final class ChunkExpander() {
  /// Starts a run with no message or call open. Each run needs its own
  /// expander, which remembers the open message or call of each sender.
  this;

  // The id of the open message or call of each sender, which is its
  // `subagentRunId`, or null for the parent. A sender is in one map at most.
  final _messageIds = <String?, String>{};
  final _toolCallIds = <String?, String>{};

  /// The events that [event] stands for.
  Iterable<Map<String, Object?>> call(Map<String, Object?> event) =>
      switch (event) {
        {'type': 'TEXT_MESSAGE_CHUNK'} => _text(event),
        {'type': 'TOOL_CALL_CHUNK'} => _toolCall(event),
        _ => [event],
      };

  Iterable<Map<String, Object?>> _text(Map<String, Object?> chunk) sync* {
    final sender = _senderOf(chunk);
    switch (_candidates(chunk['messageId'], _messageIds, sender)) {
      case []:
        return;
      case [final messageId]:
        if (!_messageIds.containsValue(messageId)) {
          _messageIds[sender] = messageId;
          _toolCallIds.remove(sender);
        }
        if (chunk['delta'] case final String delta) {
          yield {
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': messageId,
            'delta': delta,
          };
        }
      case _:
        yield _refuse(chunk);
    }
  }

  Iterable<Map<String, Object?>> _toolCall(Map<String, Object?> chunk) sync* {
    final sender = _senderOf(chunk);
    switch (_candidates(chunk['toolCallId'], _toolCallIds, sender)) {
      case []:
        return;
      case [final toolCallId]:
        if (!_toolCallIds.containsValue(toolCallId)) {
          if (chunk['toolCallName'] case final String name) {
            _toolCallIds[sender] = toolCallId;
            _messageIds.remove(sender);
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
        yield _refuse(chunk);
    }
  }
}

/// The `subagentRunId` of [chunk] when it is a string, else null for the
/// parent.
String? _senderOf(Map<String, Object?> chunk) =>
    switch (chunk['subagentRunId']) {
      final String sender => sender,
      _ => null,
    };

/// The ids a chunk can belong to: its own [id] when it is a string, else the
/// open id of its [sender], else, for the parent only, the open id of every
/// subagent.
List<String> _candidates(
  Object? id,
  Map<String?, String> openIds,
  String? sender,
) {
  if (id is String) {
    return [id];
  }
  if (openIds[sender] case final open?) {
    return [open];
  }
  return sender == null ? [...openIds.values] : [];
}

/// The `RUN_ERROR` that ends a run whose [chunk] could join several streams.
Map<String, Object?> _refuse(Map<String, Object?> chunk) => {
  'type': 'RUN_ERROR',
  'code': _ambiguousChunkCode,
  'message':
      '${chunk['type']} without an id could continue the stream of '
      'several subagents',
};
