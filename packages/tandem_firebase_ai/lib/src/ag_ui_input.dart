import 'package:tandem_firebase_ai/src/ag_ui_ids.dart';
import 'package:tandem_firebase_ai/src/json_object.dart';

/// The body of one AG-UI run as a Tandem session sends it, read into types:
/// the ids, tools and context of the run, and a thread of text messages,
/// tool calls and tool results.
final class const AgUiInput._({
  required final AgUiThreadId threadId,
  required final AgUiRunId runId,
  required final List<AgUiTool> tools,

  /// The `context` entries as JSON. A backend passes them on as data.
  required final List<Object?> context,
  required final List<AgUiMessage> messages,
}) {
  /// Throws a [FormatException] when [json] is not such a body.
  factory read(JsonObject json) => switch (json) {
    {
      'threadId': final String threadId,
      'runId': final String runId,
      'tools': final List<Object?> tools,
      'context': final List<Object?> context,
      'messages': final List<Object?> messages,
    } =>
      ._(
        threadId: AgUiThreadId(threadId),
        runId: AgUiRunId(runId),
        tools: [for (final tool in tools) .read(tool)],
        context: context,
        messages: [for (final message in messages) .read(message)],
      ),
    _ => throw FormatException('Not the body of an AG-UI run.', json),
  };

  Set<ToolName> get toolNames => {for (final tool in tools) tool.name};
}

/// A tool the run offers the agent.
final class const AgUiTool({
  required final ToolName name,
  required final String description,

  /// The JSON Schema of the tool's arguments.
  required final JsonObject parameters,
}) {
  factory read(Object? json) => switch (json) {
    {
      'name': final String name,
      'description': final String description,
      'parameters': final JsonObject parameters,
    } =>
      .new(
        name: ToolName(name),
        description: description,
        parameters: parameters,
      ),
    _ => throw FormatException('Not a tool of an AG-UI run.', json),
  };
}

sealed class const AgUiMessage() {
  factory read(Object? json) => switch (json) {
    {'role': 'user', 'content': final String text} => AgUiUserMessage(text),
    {'role': 'assistant'} && final JsonObject message =>
      AgUiAssistantMessage.tryRead(message) ?? const AgUiOtherMessage(),
    {
      'role': 'tool',
      'toolCallId': final String toolCallId,
      'content': final String content,
    } =>
      AgUiToolMessage(.wire(toolCallId), content),
    _ => const AgUiOtherMessage(),
  };
}

final class const AgUiUserMessage(final String text) extends AgUiMessage;

/// What the agent said and called in one answer. [metadata] is what the
/// backend attached to the message when it streamed it.
final class const AgUiAssistantMessage({
  required final String text,
  required final List<AgUiToolCall> toolCalls,
  required final JsonObject metadata,
}) extends AgUiMessage {
  /// Null for a message whose content is not text.
  static AgUiAssistantMessage? tryRead(JsonObject json) {
    // Tandem leaves out a field that is empty.
    final text = json['content'] ?? '';
    final toolCalls = json['toolCalls'] ?? const <Object?>[];
    final metadata = json['metadata'] ?? const <String, Object?>{};
    if (text is! String ||
        toolCalls is! List<Object?> ||
        metadata is! JsonObject) {
      return null;
    }

    return AgUiAssistantMessage(
      text: text,
      toolCalls: [for (final call in toolCalls) .read(call)],
      metadata: metadata,
    );
  }
}

/// A message this reader has no type for: another role, or content that is
/// not text, such as the content parts of a backend tool's result.
final class const AgUiOtherMessage() extends AgUiMessage;

/// The result of the call [toolCallId], as text.
final class const AgUiToolMessage(
  final ToolCallId toolCallId,
  final String content,
) extends AgUiMessage;

/// A call in a message of the agent.
final class const AgUiToolCall({
  required final ToolCallId id,
  required final ToolName name,

  /// The arguments as JSON text.
  required final String argumentsJson,
}) {
  factory read(Object? json) => switch (json) {
    {
      'id': final String id,
      'function': {
        'name': final String name,
        'arguments': final String argumentsJson,
      },
    } =>
      .new(id: .wire(id), name: ToolName(name), argumentsJson: argumentsJson),
    _ => throw FormatException('Not a tool call of an AG-UI message.', json),
  };
}
