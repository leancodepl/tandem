/// One event of an AG-UI run, reduced to what the session reads.
sealed class const AgentEvent() {
  /// Reads one decoded event of the stream. Never throws: an event of any
  /// other type, and an event of a known type that lacks a field it needs or
  /// has one of the wrong type, is an [IgnoredEvent].
  factory fromJson(Map<String, Object?> json) => switch (json) {
    {'type': 'RUN_FINISHED'} => const RunFinished(),
    {'type': 'RUN_ERROR'} => RunError(
      _string(json['code']),
      _string(json['message']),
    ),
    {
      'type': 'TEXT_MESSAGE_CONTENT',
      'messageId': final String messageId,
      'delta': final String delta,
    } =>
      TextDelta(messageId, delta),
    {
      'type': 'TOOL_CALL_START',
      'toolCallId': final String toolCallId,
      'toolCallName': final String name,
    } =>
      ToolCallStarted(toolCallId, name),
    {
      'type': 'TOOL_CALL_ARGS',
      'toolCallId': final String toolCallId,
      'delta': final String delta,
    } =>
      ToolCallArgs(toolCallId, delta),
    _ => const IgnoredEvent(),
  };
}

final class const RunFinished() extends AgentEvent;

final class const RunError(final String? code, final String? message)
    extends AgentEvent;

final class const TextDelta(final String messageId, final String delta)
    extends AgentEvent;

final class const ToolCallStarted(final String toolCallId, final String name)
    extends AgentEvent;

final class const ToolCallArgs(final String toolCallId, final String delta)
    extends AgentEvent;

final class const IgnoredEvent() extends AgentEvent;

String? _string(Object? value) => value is String ? value : null;
