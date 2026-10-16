import 'dart:convert';

import 'package:tandem/src/protocol/wire/json_reader.dart';

/// One message of a session's history, as AG-UI sends it in every run.
///
/// AG-UI is stateless on the wire: every run carries the whole history, so
/// the agent backend sees what the user wrote, what it answered, which tools
/// it called and what they returned. Tandem keeps this history itself and
/// sends it in `RunInput.messages`.
sealed class WireMessage {
  const WireMessage(this.id);

  /// Parses an AG-UI message, reading camelCase or snake_case keys.
  ///
  /// Returns `null` for roles Tandem does not keep (developer, system,
  /// activity, reasoning) and for a message without an `id`. Never throws.
  static WireMessage? fromJson(Map<String, Object?> json) {
    final reader = JsonReader(json);
    final id = reader.string('id');
    if (id == null) {
      return null;
    }
    switch (reader.string('role')) {
      case 'user':
        return WireUserMessage(id, contentText(json['content']) ?? '');
      case 'assistant':
        final calls = reader.list('toolCalls', 'tool_calls') ?? const [];
        return WireAssistantMessage(
          id,
          content: contentText(json['content']),
          toolCalls: [
            for (final call in calls)
              if (call is Map<String, Object?>) ?WireToolCall._fromJson(call),
          ],
        );
      case 'tool':
        final toolCallId = reader.string('toolCallId', 'tool_call_id');
        if (toolCallId == null) {
          return null;
        }
        return WireToolMessage(
          id,
          toolCallId: toolCallId,
          content: contentText(json['content']) ?? '',
        );
      default:
        return null;
    }
  }

  /// The message id, unique in the session.
  final String id;

  /// The AG-UI JSON of this message, with camelCase keys.
  Map<String, Object?> toJson();
}

/// What the user typed.
final class WireUserMessage extends WireMessage {
  /// Creates a user message.
  const WireUserMessage(super.id, this.content);

  /// The text.
  final String content;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'role': 'user',
    'content': content,
  };
}

/// What the agent said, the tools it called, or both.
///
/// A tool call is part of an assistant message on the wire. Some backends
/// (ag-ui-adk among them) stream tool calls without saying which message they
/// belong to, so Tandem then creates the assistant message itself.
final class WireAssistantMessage extends WireMessage {
  /// Creates an assistant message.
  const WireAssistantMessage(
    super.id, {
    this.content,
    this.toolCalls = const [],
  });

  /// The text, or `null` when the message only calls tools.
  final String? content;

  /// The tool calls, in the order the agent made them.
  final List<WireToolCall> toolCalls;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'role': 'assistant',
    'content': ?content,
    if (toolCalls.isNotEmpty)
      'toolCalls': [for (final call in toolCalls) call.toJson()],
  };
}

/// The answer to one tool call, sent back to the agent in a later run.
final class WireToolMessage extends WireMessage {
  /// Creates a tool message.
  const WireToolMessage(
    super.id, {
    required this.toolCallId,
    required this.content,
  });

  /// The id of the call this message answers.
  final String toolCallId;

  /// The answer, usually a JSON-encoded object such as
  /// `{"status":"ok","result":...}`.
  final String content;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'role': 'tool',
    'content': content,
    'toolCallId': toolCallId,
  };
}

/// One tool call inside a [WireAssistantMessage].
final class WireToolCall {
  /// Creates a tool call.
  const WireToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  static WireToolCall? _fromJson(Map<String, Object?> json) {
    final reader = JsonReader(json);
    final id = reader.string('id');
    final function = reader.map('function');
    if (id == null || function == null) {
      return null;
    }
    final functionReader = JsonReader(function);
    final name = functionReader.string('name');
    if (name == null) {
      return null;
    }
    final arguments = function['arguments'];
    return WireToolCall(
      id: id,
      name: name,
      arguments: switch (arguments) {
        null => '{}',
        final String text => text,
        final other => jsonEncode(other),
      },
    );
  }

  /// The tool call id, chosen by the agent.
  final String id;

  /// The name of the tool.
  final String name;

  /// The arguments as a JSON-encoded object, `'{}'` when there are none.
  final String arguments;

  /// The AG-UI JSON of this call.
  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': arguments},
  };
}
