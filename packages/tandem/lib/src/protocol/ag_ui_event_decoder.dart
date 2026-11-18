import 'package:tandem/src/errors.dart';
import 'package:tandem/src/frozen_json.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/events.dart';

/// Returns [IgnoredEvent] for unknown events or invalid required fields.
/// Interrupts and malformed run outcomes become [RunOutcome.unsupported].
/// Throws a [FormatException] for `metadata` that is not a JSON object.
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
  AgUiEventTypes.textMessageStart: _decodeTextStarted,
  AgUiEventTypes.textMessageContent: _decodeTextDelta,
  AgUiEventTypes.textMessageEnd: _decodeTextEnded,
  AgUiEventTypes.toolCallStart: _decodeToolCallStarted,
  AgUiEventTypes.toolCallArgs: _decodeToolCallArgs,
  AgUiEventTypes.toolCallEnd: _decodeToolCallEnded,
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

AgentEvent _decodeTextStarted(JsonObject json) =>
    switch (json[AgUiFields.messageId]) {
      final String messageId => TextStarted(
        messageId,
        metadata: _metadata(json),
      ),
      _ => const IgnoredEvent(),
    };

AgentEvent _decodeTextEnded(JsonObject json) =>
    switch (json[AgUiFields.messageId]) {
      final String messageId => TextEnded(messageId, metadata: _metadata(json)),
      _ => const IgnoredEvent(),
    };

AgentEvent _decodeTextDelta(JsonObject json) {
  final messageId = json[AgUiFields.messageId];
  final delta = json[AgUiFields.delta];
  if (messageId is! String || delta is! String) {
    return const IgnoredEvent();
  }

  return TextDelta(messageId, delta, metadata: _metadata(json));
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
    parentMessageId: _tryString(json[AgUiFields.parentMessageId]),
    metadata: _metadata(json),
  );
}

AgentEvent _decodeToolCallArgs(JsonObject json) {
  final toolCallId = json[AgUiFields.toolCallId];
  final delta = json[AgUiFields.delta];
  if (toolCallId is! String || delta is! String) {
    return const IgnoredEvent();
  }

  return ToolCallArgs(toolCallId, delta, metadata: _metadata(json));
}

AgentEvent _decodeToolCallEnded(JsonObject json) =>
    switch (json[AgUiFields.toolCallId]) {
      final String toolCallId => ToolCallEnded(
        toolCallId,
        metadata: _metadata(json),
      ),
      _ => const IgnoredEvent(),
    };

AgentEvent _decodeToolCallResult(JsonObject json) {
  final content = switch (json[AgUiFields.content]) {
    final String text => ToolResultContent.text(text),
    final List<Object?> parts => ToolResultContent.parts(parts),
    _ => null,
  };

  return switch ((
    json[AgUiFields.messageId],
    json[AgUiFields.toolCallId],
    content,
  )) {
    (final String messageId, final String toolCallId, final content?) =>
      ToolCallResult(messageId, toolCallId, content, metadata: _metadata(json)),
    _ => const IgnoredEvent(),
  };
}

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

JsonObject _metadata(JsonObject json) {
  if (json.containsKey(AgUiFields.metadata)) {
    return switch (json[AgUiFields.metadata]) {
      final Map<Object?, Object?> metadata => frozenJson(metadata),
      _ => throw const FormatException('AG-UI metadata must be a JSON object.'),
    };
  }
  return const {};
}
