/// One event of an AG-UI run, reduced to what the session reads.
sealed class const AgentEvent() {
  /// Read with [AgentEvent.fromJson].
  this;

  /// Reads one decoded event of the stream. Never throws: an event of any
  /// other type, and an event of a known type that lacks a field it needs or
  /// has one of the wrong type, is an [IgnoredEvent].
  factory fromJson(Map<String, Object?> json) => switch (json) {
    {'type': 'RUN_FINISHED'} => const RunFinished(),
    {'type': 'RUN_ERROR'} => RunFailed(
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

/// The run ended without an error.
final class const RunFinished() extends AgentEvent {
  /// The run ended.
  this;
}

/// The run ended with an error, whatever fields its `RUN_ERROR` has. They go
/// only to the logs: the message can be 2 KB of the model provider's JSON and
/// is never shown.
final class const RunFailed(final String? code, final String? message)
    extends AgentEvent {
  /// The run ended with the error [code], such as `EXECUTION_ERROR`, and
  /// [message].
  this;
}

/// The agent adds a piece of text to a text message.
final class const TextDelta(final String messageId, final String delta)
    extends AgentEvent {
  /// The message [messageId] grows by [delta].
  this;
}

/// The agent starts a call of a tool.
final class const ToolCallStarted(final String toolCallId, final String name)
    extends AgentEvent {
  /// The call [toolCallId] of the tool [name] starts.
  this;
}

/// The agent adds a piece of JSON to the arguments of a call.
final class const ToolCallArgs(final String toolCallId, final String delta)
    extends AgentEvent {
  /// The arguments of the call [toolCallId] grow by [delta].
  this;
}

/// Every event the session does not read: run start, starts and ends of
/// messages, ends of calls, tool results, state and reasoning events, and
/// unknown types.
final class const IgnoredEvent() extends AgentEvent {
  /// The session reads nothing in this event.
  this;
}

String? _string(Object? value) => value is String ? value : null;
