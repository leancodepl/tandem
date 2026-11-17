import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/ag_ui_ids.dart';
import 'package:uuid/uuid.dart';

/// The body of one AG-UI run.
extension type RunInput._(JsonObject json) implements JsonObject {
  /// A new run of [threadId] with the whole conversation of the thread as
  /// [messages], the agent's [state], and the [tools] and [context] of this
  /// run.
  factory({
    required String threadId,
    required List<AgUiMessage> messages,
    required JsonObject state,
    required List<JsonObject> tools,
    required List<JsonObject> context,
  }) => ._({
    AgUiFields.threadId: threadId,
    AgUiFields.runId: const Uuid().v4(),
    AgUiFields.state: state,
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
    AgUiFields.id: MessageId.local().value,
    AgUiFields.role: AgUiMessageRoles.user,
    AgUiFields.content: text,
  });

  /// A message of the agent under its id, with what it said and its calls.
  factory assistant(
    MessageId id, {
    String? text,
    List<AgUiToolCall> toolCalls = const [],
  }) => ._({
    AgUiFields.id: id.value,
    AgUiFields.role: AgUiMessageRoles.assistant,
    AgUiFields.content: ?text,
    if (toolCalls.isNotEmpty) AgUiFields.toolCalls: toolCalls,
  });

  /// The result of the call [toolCallId]: the app's answer, or for a call
  /// that ran on the server, its `TOOL_CALL_RESULT` under that event's id.
  factory toolResult({
    required MessageId id,
    required ToolCallId toolCallId,
    required ToolResultContent content,
  }) => ._({
    AgUiFields.id: id.value,
    AgUiFields.role: AgUiMessageRoles.tool,
    AgUiFields.toolCallId: toolCallId.value,
    AgUiFields.content: content,
  });
}

/// A call in a message of the agent.
extension type AgUiToolCall._(JsonObject json) implements JsonObject {
  factory({
    required ToolCallId id,
    required String name,
    required String arguments,
  }) => ._({
    AgUiFields.id: id.value,
    AgUiFields.type: AgUiToolCallTypes.function,
    AgUiFields.function: {
      AgUiFields.name: name,
      AgUiFields.arguments: arguments,
    },
  });
}
