import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The body of one AG-UI run: the whole conversation of the thread as
/// [messages], plus what [listing] shares with the agent.
JsonObject runInput({
  required String threadId,
  required String runId,
  required List<JsonObject> messages,
  required AgentListing listing,
}) => {
  AgUiFields.threadId: threadId,
  AgUiFields.runId: runId,
  AgUiFields.state: <String, Object?>{},
  AgUiFields.messages: messages,
  AgUiFields.tools: listing.tools,
  AgUiFields.context: listing.context,
  AgUiFields.forwardedProps: <String, Object?>{},
};

JsonObject userMessage(String id, String text) => {
  AgUiFields.id: id,
  AgUiFields.role: AgUiMessageRoles.user,
  AgUiFields.content: text,
};

/// A text the agent said, under the id of its `TEXT_MESSAGE_START`.
JsonObject assistantText(String id, String text) => {
  AgUiFields.id: id,
  AgUiFields.role: AgUiMessageRoles.assistant,
  AgUiFields.content: text,
};

JsonObject assistantToolCall(
  String toolCallId,
  String name,
  String arguments,
) => {
  // Never the bare call id: ag-ui-adk marks every message id it has seen as
  // processed, and would swallow the answer that comes later.
  AgUiFields.id: 'asst-$toolCallId',
  AgUiFields.role: AgUiMessageRoles.assistant,
  AgUiFields.toolCalls: [
    {
      AgUiFields.id: toolCallId,
      AgUiFields.type: AgUiToolCallTypes.function,
      AgUiFields.function: {
        AgUiFields.name: name,
        AgUiFields.arguments: arguments,
      },
    },
  ],
};

JsonObject toolAnswer(String toolCallId, String content) => {
  AgUiFields.id: 'tool-$toolCallId',
  AgUiFields.role: AgUiMessageRoles.tool,
  AgUiFields.toolCallId: toolCallId,
  AgUiFields.content: content,
};
