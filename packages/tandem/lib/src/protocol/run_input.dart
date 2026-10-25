import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:uuid/uuid.dart';

/// The body of one AG-UI run.
extension type RunInput._(JsonObject json) implements JsonObject {
  /// A new run of [threadId] with the whole conversation of the thread as
  /// [messages], and the [tools] and [context] of this run.
  factory({
    required String threadId,
    required List<AgUiMessage> messages,
    required List<JsonObject> tools,
    required List<JsonObject> context,
  }) => ._({
    AgUiFields.threadId: threadId,
    AgUiFields.runId: const Uuid().v4(),
    AgUiFields.state: <String, Object?>{},
    AgUiFields.messages: messages,
    AgUiFields.tools: tools,
    AgUiFields.context: context,
    AgUiFields.forwardedProps: <String, Object?>{},
  });
}

/// A message of the thread, as every run sends it again.
extension type AgUiMessage._(JsonObject json) implements JsonObject {
  /// What the user wrote, under a new id.
  factory user(String text) => ._({
    AgUiFields.id: const Uuid().v4(),
    AgUiFields.role: AgUiMessageRoles.user,
    AgUiFields.content: text,
  });

  /// A text the agent said, under the id of its `TEXT_MESSAGE_START`.
  factory assistantText(String id, String text) => ._({
    AgUiFields.id: id,
    AgUiFields.role: AgUiMessageRoles.assistant,
    AgUiFields.content: text,
  });

  factory assistantToolCall(
    String toolCallId,
    String name,
    String arguments,
  ) => ._({
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
  });

  factory toolAnswer(String toolCallId, String content) => ._({
    AgUiFields.id: 'tool-$toolCallId',
    AgUiFields.role: AgUiMessageRoles.tool,
    AgUiFields.toolCallId: toolCallId,
    AgUiFields.content: content,
  });
}
