/// One event of an AG-UI run, reduced to what the session reads.
sealed class const AgentEvent() {
  /// For the kinds of events below.
  this;

  /// Reads one decoded event of the stream. Never throws: an event of any
  /// other type, and an event of a known type that lacks a field or has one of
  /// the wrong type, is an [IgnoredEvent].
  factory fromJson(Map<String, Object?> json) => switch (json) {
    {'type': 'RUN_FINISHED'} => const RunFinished(),
    {'type': 'RUN_ERROR', 'code': final String code} => RunFailed(code),
    {'type': 'TEXT_MESSAGE_START', 'messageId': final String messageId} =>
      TextStarted(messageId),
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

/// The run ended with an error. Only the code is kept: the message can be
/// 2 KB of the model provider's JSON and is not for the user.
final class const RunFailed(final String code) extends AgentEvent {
  /// The run ended with the error [code], such as `EXECUTION_ERROR`.
  this;
}

/// The agent starts a text message.
final class const TextStarted(final String messageId) extends AgentEvent {
  /// The message [messageId] starts.
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

/// Every event the session does not read: run start, ends of messages and
/// calls, tool results, state and reasoning events, and unknown types.
final class const IgnoredEvent() extends AgentEvent {
  /// The session reads nothing in this event.
  this;
}
