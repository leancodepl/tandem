/// AG-UI event names recognized or emitted by Tandem.
abstract final class AgUiEventTypes() {
  static const runStarted = 'RUN_STARTED';
  static const runFinished = 'RUN_FINISHED';
  static const runError = 'RUN_ERROR';

  static const stepStarted = 'STEP_STARTED';
  static const stepFinished = 'STEP_FINISHED';

  static const textMessageStart = 'TEXT_MESSAGE_START';
  static const textMessageContent = 'TEXT_MESSAGE_CONTENT';
  static const textMessageEnd = 'TEXT_MESSAGE_END';
  static const textMessageChunk = 'TEXT_MESSAGE_CHUNK';

  static const toolCallStart = 'TOOL_CALL_START';
  static const toolCallArgs = 'TOOL_CALL_ARGS';
  static const toolCallEnd = 'TOOL_CALL_END';
  static const toolCallResult = 'TOOL_CALL_RESULT';
  static const toolCallChunk = 'TOOL_CALL_CHUNK';

  static const stateSnapshot = 'STATE_SNAPSHOT';
  static const stateDelta = 'STATE_DELTA';
  static const messagesSnapshot = 'MESSAGES_SNAPSHOT';

  static const reasoningStart = 'REASONING_START';
  static const reasoningMessageStart = 'REASONING_MESSAGE_START';
  static const reasoningMessageContent = 'REASONING_MESSAGE_CONTENT';
  static const reasoningMessageEnd = 'REASONING_MESSAGE_END';
  static const reasoningMessageChunk = 'REASONING_MESSAGE_CHUNK';
  static const reasoningEnd = 'REASONING_END';

  static const subagentFinished = 'SUBAGENT_FINISHED';
  static const subagentError = 'SUBAGENT_ERROR';

  static const custom = 'CUSTOM';
}

abstract final class AgUiOutcomeTypes() {
  static const success = 'success';
  static const cancelled = 'cancelled';
  static const interrupt = 'interrupt';
}

/// AG-UI message roles emitted by Tandem.
abstract final class AgUiMessageRoles() {
  static const user = 'user';
  static const assistant = 'assistant';
  static const tool = 'tool';
}

abstract final class AgUiToolCallTypes() {
  static const function = 'function';
}

/// AG-UI wire fields read or written by Tandem.
/// https://docs.ag-ui.com/spec/1.0/schema
abstract final class AgUiFields() {
  static const type = 'type';
  static const threadId = 'threadId';
  static const runId = 'runId';
  static const subagentRunId = 'subagentRunId';

  static const state = 'state';
  static const messages = 'messages';
  static const tools = 'tools';
  static const context = 'context';
  static const forwardedProps = 'forwardedProps';

  static const outcome = 'outcome';
  static const code = 'code';
  static const message = 'message';

  static const id = 'id';
  static const role = 'role';
  static const content = 'content';
  static const messageId = 'messageId';
  static const delta = 'delta';

  static const toolCalls = 'toolCalls';
  static const toolCallId = 'toolCallId';
  static const toolCallName = 'toolCallName';
  static const function = 'function';
  static const arguments = 'arguments';

  static const name = 'name';
  static const description = 'description';
  static const parameters = 'parameters';
  static const value = 'value';
}

typedef JsonObject = Map<String, Object?>;
