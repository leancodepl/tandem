/// One event of an AG-UI run, reduced to what the session reads.
sealed class const AgentEvent() {
  /// Reads one decoded event of the stream. Never throws: an event of any
  /// other type, and an event of a known type that lacks a field it needs or
  /// has one of the wrong type, is an [IgnoredEvent]. A `RUN_FINISHED` whose
  /// outcome has the wrong shape is [RunOutcome.unsupported].
  factory fromJson(Map<String, Object?> json) => switch (json) {
    {'type': 'RUN_FINISHED'} => RunFinished(switch (json['outcome']) {
      {'type': 'cancelled'} => .cancelled,
      {'type': 'interrupt'} => .unsupported,
      // AG-UI 1.0 drops an outcome type it does not know, and older SDKs
      // send `outcome: null`: both mean success.
      null || {'type': String()} => .success,
      _ => .unsupported,
    }),
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

/// How a run ended, from the `outcome` of its `RUN_FINISHED`.
enum RunOutcome() {
  success,
  cancelled,

  /// An interrupt, which Tandem cannot follow, or an outcome of the wrong
  /// shape.
  unsupported,
}

final class const RunFinished([final RunOutcome outcome = .success])
    extends AgentEvent;

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
