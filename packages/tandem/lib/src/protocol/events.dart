import 'package:tandem/src/errors.dart';

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

final class const RunError(final RunErrorCode? code, final String? message)
    extends AgentEvent;

final class const TextDelta(final String messageId, final String delta)
    extends AgentEvent;

final class const ToolCallStarted(final String toolCallId, final String name)
    extends AgentEvent;

final class const ToolCallArgs(final String toolCallId, final String delta)
    extends AgentEvent;

/// The result of a tool that ran on the backend.
final class const ToolCallResult(final String toolCallId) extends AgentEvent;

final class const IgnoredEvent() extends AgentEvent;
