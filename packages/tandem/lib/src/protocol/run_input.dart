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

  /// A message of the agent under its id, with what it said and its calls.
  factory assistant(
    String id, {
    String? text,
    List<AgUiToolCall> toolCalls = const [],
  }) => ._({
    AgUiFields.id: id,
    AgUiFields.role: AgUiMessageRoles.assistant,
    AgUiFields.content: ?text,
    if (toolCalls.isNotEmpty) AgUiFields.toolCalls: toolCalls,
  });

  /// The app's answer to a call of a listed method.
  factory toolAnswer(String toolCallId, String content) =>
      AgUiMessage.toolResult('tool-$toolCallId', toolCallId, content);

  /// The result of a call, under the id of its `TOOL_CALL_RESULT` for a call
  /// that ran on the server.
  factory toolResult(String id, String toolCallId, String content) => ._({
    AgUiFields.id: id,
    AgUiFields.role: AgUiMessageRoles.tool,
    AgUiFields.toolCallId: toolCallId,
    AgUiFields.content: content,
  });
}

/// A call in a message of the agent.
extension type AgUiToolCall._(JsonObject json) implements JsonObject {
  factory(String id, String name, String arguments) => ._({
    AgUiFields.id: id,
    AgUiFields.type: AgUiToolCallTypes.function,
    AgUiFields.function: {
      AgUiFields.name: name,
      AgUiFields.arguments: arguments,
    },
  });
}
