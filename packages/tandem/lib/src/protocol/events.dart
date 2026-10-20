/// The part of an agent's run that the session handles.
sealed class const AgentEvent();

enum RunOutcome() {
  success,
  cancelled,

  /// The session cannot continue this run.
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
