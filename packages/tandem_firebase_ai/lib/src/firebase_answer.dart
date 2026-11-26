import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:tandem_firebase_ai/src/ag_ui_ids.dart';
import 'package:tandem_firebase_ai/src/ag_ui_input.dart';
import 'package:tandem_firebase_ai/src/json_object.dart';
import 'package:uuid/uuid.dart';

/// Gemini's complete answer to one run.
///
/// Firebase must get an answer with tool calls back as it was, with the
/// thought signatures of its [parts]. So the answer travels in the metadata
/// of the assistant message it became, and a later run sends it back only
/// while that message still has the answer's text and calls.
final class const FirebaseAnswer({
  /// The text the user saw.
  required final String text,
  required final List<ProposedCall> calls,

  /// Every part as Firebase sent it: the same JSON, in the same order.
  required final List<JsonObject> parts,
}) {
  static const _metadataKey = 'tandem_firebase_ai';
  static const _version = 1;

  /// The answer that the connection [by] stored in [message]. Null when the
  /// message has none, when another connection stored it, or when Tandem
  /// has other text or calls for the message now, such as after a Stop.
  static FirebaseAnswer? storedIn(
    AgUiAssistantMessage message, {
    required ConnectionId by,
  }) {
    final answer = _read(message.metadata[_metadataKey], storedBy: by);
    if (answer == null) return null;

    return answer._matches(message) ? answer : null;
  }

  /// The metadata that keeps this answer with its assistant message.
  JsonObject toMetadata({required ConnectionId storedBy}) => {
    _metadataKey: {
      'version': _version,
      'connection': storedBy.value,
      'text': text,
      'calls': [for (final call in calls) call.toJson()],
      'parts': parts,
    },
  };

  /// The model content Firebase gets back.
  // `UnknownPart` sends the JSON as it is. The SDK's typed parts take a
  // thought signature only through constructors it keeps for its tests.
  Content get content => .model(parts.map(UnknownPart.new));

  /// What [toMetadata] wrote for [storedBy]. Anything else is no answer.
  static FirebaseAnswer? _read(
    Object? metadata, {
    required ConnectionId storedBy,
  }) {
    if (metadata
        case {
          'version': _version,
          'connection': final String connection,
          'text': final String text,
          'calls': final List<Object?> storedCalls,
          'parts': final List<Object?> storedParts,
        }
        when connection == storedBy.value) {
      final calls = [
        for (final call in storedCalls) ?ProposedCall.tryRead(call),
      ];
      final parts = [...storedParts.whereType<JsonObject>()];
      final isWhole =
          calls.length == storedCalls.length &&
          parts.length == storedParts.length;
      if (isWhole) {
        return FirebaseAnswer(text: text, calls: calls, parts: parts);
      }
    }
    return null;
  }

  bool _matches(AgUiAssistantMessage message) {
    if (text != message.text) return false;
    if (calls.length != message.toolCalls.length) return false;

    for (final (index, call) in calls.indexed) {
      if (!call.matches(message.toolCalls[index])) return false;
    }
    return true;
  }
}

/// A call Gemini proposed, as both sides name it: Tandem runs it and returns
/// its result under [id], and Firebase reads that result under
/// [functionCallId].
final class const ProposedCall({
  required final ToolCallId id,

  /// Null when Firebase gave the call no ID.
  required final FunctionCallId? functionCallId,
  required final AgUiToolName name,

  /// The arguments, a JSON object, as text.
  required final String argumentsJson,
}) {
  /// A call of Gemini's answer, under a new [id].
  factory of(FunctionCall call) => .new(
    id: .unique(),
    functionCallId: .orNull(call.id),
    name: AgUiToolName(call.name),
    argumentsJson: jsonEncode(call.args),
  );

  /// What [toJson] wrote, or null for anything else.
  static ProposedCall? tryRead(Object? json) => switch (json) {
    {
      'id': final String id,
      'functionCallId': final String? functionCallId,
      'name': final String name,
      'arguments': final String argumentsJson,
    } =>
      ProposedCall(
        id: .wire(id),
        functionCallId: .orNull(functionCallId),
        name: AgUiToolName(name),
        argumentsJson: argumentsJson,
      ),
    _ => null,
  };

  JsonObject toJson() => {
    'id': id.value,
    'functionCallId': functionCallId?.value,
    'name': name.value,
    'arguments': argumentsJson,
  };

  bool matches(AgUiToolCall call) =>
      id == call.id && name == call.name && argumentsJson == call.argumentsJson;
}

/// The ID Firebase gave a function call, which the call's response repeats.
extension type const FunctionCallId(String value) {
  static FunctionCallId? orNull(String? value) =>
      value == null ? null : FunctionCallId(value);
}

/// Names the connection that stored an answer. A thread goes on only with
/// that connection, because another one may ask another model.
extension type const ConnectionId._(String value) {
  new unique() : this._(const Uuid().v4());
}
