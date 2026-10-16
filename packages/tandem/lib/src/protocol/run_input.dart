import 'package:tandem/src/agent_list.dart';

/// The id of the assistant message that carries a tool call is this prefix
/// plus the call id, never the bare call id: ag-ui-adk marks every message id
/// it has seen as processed, so a message with the bare call id would make it
/// swallow the answer that comes later.
const assistantToolCallPrefix = 'asst-';

/// The id of the message that answers a tool call is this prefix plus the
/// call id.
const toolAnswerPrefix = 'tool-';

/// The body of one AG-UI run: the whole conversation of the thread as
/// [messages], plus what [listing] shares with the agent.
Map<String, Object?> runInput({
  required String threadId,
  required String runId,
  required List<Map<String, Object?>> messages,
  required AgentListing listing,
}) => {
  'threadId': threadId,
  'runId': runId,
  'state': <String, Object?>{},
  'messages': messages,
  'tools': listing.tools,
  'context': listing.context,
  'forwardedProps': <String, Object?>{},
};

/// A message the user typed.
Map<String, Object?> userMessage(String id, String text) => {
  'id': id,
  'role': 'user',
  'content': text,
};

/// A text the agent said, under the id of its `TEXT_MESSAGE_START`.
Map<String, Object?> assistantText(String id, String text) => {
  'id': id,
  'role': 'assistant',
  'content': text,
};

/// A call of a listed method the agent made, with its JSON [arguments].
Map<String, Object?> assistantToolCall(
  String toolCallId,
  String name,
  String arguments,
) => {
  'id': '$assistantToolCallPrefix$toolCallId',
  'role': 'assistant',
  'toolCalls': [
    {
      'id': toolCallId,
      'type': 'function',
      'function': {'name': name, 'arguments': arguments},
    },
  ],
};

/// The answer to the call [toolCallId], with [content] as a JSON string.
Map<String, Object?> toolAnswer(String toolCallId, String content) => {
  'id': '$toolAnswerPrefix$toolCallId',
  'role': 'tool',
  'toolCallId': toolCallId,
  'content': content,
};
