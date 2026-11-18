import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

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

/// Text and tool calls streamed into the assistant messages of one run.
sealed class const RunOutput() extends AgentEvent;

/// The start of a message, which fixes its place among the run's messages.
final class const TextStarted(
  final String messageId, {
  final JsonObject metadata = const {},
}) extends RunOutput;

final class const TextDelta(
  final String messageId,
  final String delta, {
  final JsonObject metadata = const {},
}) extends RunOutput;

final class const TextEnded(
  final String messageId, {
  final JsonObject metadata = const {},
}) extends RunOutput;

final class const ToolCallStarted(
  final String toolCallId,
  final String name, {

  /// The agent's message that holds the call, when the server names it.
  final String? parentMessageId,
  final JsonObject metadata = const {},
}) extends RunOutput;

final class const ToolCallArgs(
  final String toolCallId,
  final String delta, {
  final JsonObject metadata = const {},
}) extends RunOutput;

final class const ToolCallEnded(
  final String toolCallId, {
  final JsonObject metadata = const {},
}) extends RunOutput;

/// The result of a tool that ran on the backend.
final class const ToolCallResult(
  final String messageId,
  final String toolCallId,
  final ToolResultContent content, {
  final JsonObject metadata = const {},
}) extends RunOutput;

sealed class const StateUpdate() extends AgentEvent;

/// The agent's whole state, as JSON, which replaces the one the app has.
final class const StateSnapshot(final Object? snapshot) extends StateUpdate;

/// JSON Patch operations (RFC 6902) on the agent's state, as JSON.
final class const StateDelta(final Object? delta) extends StateUpdate;

final class const IgnoredEvent() extends AgentEvent;
