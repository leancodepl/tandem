import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/events.dart';

/// Returns [IgnoredEvent] for unknown events or invalid required fields.
/// Interrupts and malformed run outcomes become [RunOutcome.unsupported].
AgentEvent decodeAgUiEvent(JsonObject json) {
  final decode = _decoders[json[AgUiFields.type]];
  if (decode == null) {
    return const IgnoredEvent();
  }

  return decode(json);
}

const _decoders = <String, AgentEvent Function(JsonObject)>{
  AgUiEventTypes.runFinished: _decodeRunFinished,
  AgUiEventTypes.runError: _decodeRunError,
  AgUiEventTypes.textMessageContent: _decodeTextDelta,
  AgUiEventTypes.toolCallStart: _decodeToolCallStarted,
  AgUiEventTypes.toolCallArgs: _decodeToolCallArgs,
  AgUiEventTypes.toolCallResult: _decodeToolCallResult,
  AgUiEventTypes.stateSnapshot: _decodeStateSnapshot,
  AgUiEventTypes.stateDelta: _decodeStateDelta,
};

RunFinished _decodeRunFinished(JsonObject json) =>
    RunFinished(_decodeOutcome(json[AgUiFields.outcome]));

RunError _decodeRunError(JsonObject json) => RunError(
  _tryCode(json[AgUiFields.code]),
  _tryString(json[AgUiFields.message]),
);

AgentEvent _decodeTextDelta(JsonObject json) {
  final messageId = json[AgUiFields.messageId];
  final delta = json[AgUiFields.delta];
  if (messageId is! String || delta is! String) {
    return const IgnoredEvent();
  }

  return TextDelta(messageId, delta);
}

AgentEvent _decodeToolCallStarted(JsonObject json) {
  final toolCallId = json[AgUiFields.toolCallId];
  final name = json[AgUiFields.toolCallName];
  if (toolCallId is! String || name is! String) {
    return const IgnoredEvent();
  }

  return ToolCallStarted(
    toolCallId,
    name,
    _tryString(json[AgUiFields.parentMessageId]),
  );
}

AgentEvent _decodeToolCallArgs(JsonObject json) {
  final toolCallId = json[AgUiFields.toolCallId];
  final delta = json[AgUiFields.delta];
  if (toolCallId is! String || delta is! String) {
    return const IgnoredEvent();
  }

  return ToolCallArgs(toolCallId, delta);
}

AgentEvent _decodeToolCallResult(JsonObject json) => switch (json) {
  {
    AgUiFields.messageId: final String messageId,
    AgUiFields.toolCallId: final String toolCallId,
    AgUiFields.content: final String content,
  } =>
    ToolCallResult(messageId, toolCallId, content),
  _ => const IgnoredEvent(),
};

// AgentState checks the shape, so a wrong one is reported, not dropped.
StateSnapshot _decodeStateSnapshot(JsonObject json) =>
    StateSnapshot(json[AgUiFields.snapshot]);

StateDelta _decodeStateDelta(JsonObject json) =>
    StateDelta(json[AgUiFields.delta]);

RunOutcome _decodeOutcome(Object? json) => switch (json) {
  {AgUiFields.type: AgUiOutcomeTypes.cancelled} => .cancelled,
  {AgUiFields.type: AgUiOutcomeTypes.interrupt} => .unsupported,
  // AG-UI 1.0 drops an unknown outcome type; older SDKs send null.
  null || {AgUiFields.type: String()} => .success,
  _ => .unsupported,
};

String? _tryString(Object? value) => value is String ? value : null;

RunErrorCode? _tryCode(Object? value) =>
    value is String ? RunErrorCode(value) : null;
