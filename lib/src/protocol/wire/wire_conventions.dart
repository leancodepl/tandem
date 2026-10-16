// The session writes these shapes and the scripted agent checks and reads
// them, so change them only together.
//
// Internal: not exported.

/// What Tandem puts on the wire beyond plain AG-UI, and the keys of the
/// agent backend it must never echo.
abstract final class WireConventions {
  /// Prefix of the assistant message the session creates for a tool call
  /// that has no `parentMessageId`: `asst-<toolCallId>`.
  ///
  /// A tool call id is never used as a message id: ag-ui-adk marks message
  /// ids as processed and would then drop the call's late answer.
  static const assistantMessagePrefix = 'asst-';

  /// Prefix of the tool messages the session creates for answers of the
  /// app's tools: `tool-<uuid>`.
  static const toolMessagePrefix = 'tool-';

  /// Prefix of the state keys ag-ui-adk owns, such as `_ag_ui_thread_id`.
  static const serverKeyPrefix = '_ag_ui_';

  /// The state key in which ag-ui-adk tracks open tool calls. Echoing it
  /// back in `state` wipes the backend's list and drops later approvals.
  static const pendingToolCallsKey = 'pending_tool_calls';

  /// Whether the top-level state [key] belongs to the agent backend.
  static bool isServerKey(String key) =>
      key.startsWith(serverKeyPrefix) || key == pendingToolCallsKey;

  /// The `description` of the context entry that lists the shared-state
  /// leaves the user changed by hand since the previous run.
  ///
  /// Its `value` is a JSON array of RFC 6901 JSON Pointers into the run's
  /// `state`, such as `["/order/lines/1/quantity"]`. The entry is only sent
  /// when the list is not empty.
  static const userEditsDescription =
      'Fields of the shared state the user changed by hand since the '
      'previous run, as JSON Pointers into the state';
}
