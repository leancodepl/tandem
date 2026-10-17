import 'package:tandem/src/agent_list.dart';

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

Map<String, Object?> assistantToolCall(
  String toolCallId,
  String name,
  String arguments,
) => {
  // Never the bare call id: ag-ui-adk marks every message id it has seen as
  // processed, and would swallow the answer that comes later.
  'id': 'asst-$toolCallId',
  'role': 'assistant',
  'toolCalls': [
    {
      'id': toolCallId,
      'type': 'function',
      'function': {'name': name, 'arguments': arguments},
    },
  ],
};

Map<String, Object?> toolAnswer(String toolCallId, String content) => {
  'id': 'tool-$toolCallId',
  'role': 'tool',
  'toolCallId': toolCallId,
  'content': content,
};
