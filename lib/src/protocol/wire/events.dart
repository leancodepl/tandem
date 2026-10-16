import 'dart:convert';

import 'package:tandem/src/protocol/wire/json_reader.dart';
import 'package:tandem/src/protocol/wire/messages.dart';

/// One event of a run, as the agent backend streams it.
///
/// An AG-UI run is a stream of small JSON events: the run starts, text
/// arrives in pieces, tool calls open and close, the shared state changes,
/// the run finishes. Tandem models only the events it acts on. Every event
/// keeps the JSON it was decoded from in [json], so fields Tandem does not
/// model (such as protocol 1.0 `outcome` or `usage`) are never lost.
///
/// Decoding never throws: an unknown type, or a known type without a field
/// Tandem needs, becomes an [UnknownEvent], which the session ignores and
/// reports as a diagnostic.
sealed class WireEvent {
  const WireEvent(this.json);

  /// Decodes one event, reading camelCase or snake_case keys. Never throws.
  factory WireEvent.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    if (type is! String) {
      return UnknownEvent(json, problem: 'The event has no "type".');
    }
    final fields = _Fields(json);
    final event = switch (type) {
      'RUN_STARTED' => RunStarted(
        json,
        threadId: fields.required('threadId', 'thread_id'),
        runId: fields.required('runId', 'run_id'),
      ),
      'RUN_FINISHED' => RunFinished(json),
      'RUN_ERROR' => RunError(
        json,
        message: fields.optional('message') ?? '',
        code: fields.optional('code'),
      ),
      'TEXT_MESSAGE_START' => TextStart(
        json,
        messageId: fields.required('messageId', 'message_id'),
      ),
      'TEXT_MESSAGE_CONTENT' => TextContent(
        json,
        messageId: fields.required('messageId', 'message_id'),
        delta: fields.optional('delta') ?? '',
      ),
      'TEXT_MESSAGE_END' => TextEnd(
        json,
        messageId: fields.required('messageId', 'message_id'),
      ),
      'TEXT_MESSAGE_CHUNK' => TextChunk(
        json,
        messageId: fields.optional('messageId', 'message_id'),
        delta: fields.optional('delta'),
      ),
      'TOOL_CALL_START' => ToolCallStart(
        json,
        toolCallId: fields.required('toolCallId', 'tool_call_id'),
        toolCallName: fields.required('toolCallName', 'tool_call_name'),
        parentMessageId: fields.optional(
          'parentMessageId',
          'parent_message_id',
        ),
      ),
      'TOOL_CALL_ARGS' => ToolCallArgs(
        json,
        toolCallId: fields.required('toolCallId', 'tool_call_id'),
        delta: fields.optional('delta') ?? '',
      ),
      'TOOL_CALL_END' => ToolCallEnd(
        json,
        toolCallId: fields.required('toolCallId', 'tool_call_id'),
      ),
      'TOOL_CALL_CHUNK' => ToolCallChunk(
        json,
        toolCallId: fields.optional('toolCallId', 'tool_call_id'),
        toolCallName: fields.optional('toolCallName', 'tool_call_name'),
        parentMessageId: fields.optional(
          'parentMessageId',
          'parent_message_id',
        ),
        delta: fields.optional('delta'),
      ),
      'TOOL_CALL_RESULT' => ToolCallResult(
        json,
        messageId: fields.required('messageId', 'message_id'),
        toolCallId: fields.required('toolCallId', 'tool_call_id'),
        content: fields.content('content'),
      ),
      'STATE_SNAPSHOT' => StateSnapshot(
        json,
        snapshot: fields.object('snapshot'),
      ),
      'STATE_DELTA' => StateDelta(json, operations: fields.operations('delta')),
      'MESSAGES_SNAPSHOT' => MessagesSnapshot(
        json,
        messages: fields.messages('messages'),
      ),
      _ => null,
    };
    if (event == null) {
      return UnknownEvent(json);
    }
    if (fields.problems.isNotEmpty) {
      return UnknownEvent(json, problem: '$type: ${fields.problems.join(' ')}');
    }
    return event;
  }

  /// The event exactly as received.
  final Map<String, Object?> json;

  /// The wire `type`, such as `TOOL_CALL_START`, or an empty string when the
  /// JSON has none.
  String get type => switch (json['type']) {
    final String type => type,
    _ => '',
  };
}

/// `RUN_STARTED`: the backend accepted the run.
///
/// Some backends send `RUN_ERROR` without it when they reject a request.
final class RunStarted extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const RunStarted(super.json, {required this.threadId, required this.runId});

  /// The session's AG-UI thread id.
  final String threadId;

  /// The id of this run.
  final String runId;
}

/// `RUN_FINISHED`: the run ended normally.
///
/// It ends the run even when tool calls are still waiting for the app's
/// answer; the app answers them in the next run.
final class RunFinished extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const RunFinished(super.json);
}

/// `RUN_ERROR`: the agent backend failed the run.
final class RunError extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const RunError(super.json, {required this.message, this.code});

  /// What went wrong, as the backend put it. Empty when it gave no message.
  final String message;

  /// A machine-readable code, such as `INTERRUPT_RESUME_REQUIRED`.
  final String? code;
}

/// `TEXT_MESSAGE_START`: the agent starts a text message.
final class TextStart extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const TextStart(super.json, {required this.messageId});

  /// The id of the message.
  final String messageId;
}

/// `TEXT_MESSAGE_CONTENT`: the next piece of a text message.
final class TextContent extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const TextContent(super.json, {required this.messageId, required this.delta});

  /// The id of the message.
  final String messageId;

  /// The new text, to append. May be empty.
  final String delta;
}

/// `TEXT_MESSAGE_END`: a text message is complete.
final class TextEnd extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const TextEnd(super.json, {required this.messageId});

  /// The id of the message.
  final String messageId;
}

/// `TEXT_MESSAGE_CHUNK`: a shorthand some backends use instead of start,
/// content and end. The session expands it.
final class TextChunk extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const TextChunk(super.json, {this.messageId, this.delta});

  /// The id of the message. Required on the first chunk of a message.
  final String? messageId;

  /// The new text, to append.
  final String? delta;
}

/// `TOOL_CALL_START`: the agent starts calling a tool.
///
/// The call is complete at the matching [ToolCallEnd]. Other events, such as
/// a [StateSnapshot], may arrive while it is open.
final class ToolCallStart extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const ToolCallStart(
    super.json, {
    required this.toolCallId,
    required this.toolCallName,
    this.parentMessageId,
  });

  /// The id of the call, used by every later event of this call.
  final String toolCallId;

  /// The name of the tool.
  final String toolCallName;

  /// The assistant message this call belongs to. ag-ui-adk never sends it.
  final String? parentMessageId;
}

/// `TOOL_CALL_ARGS`: the next piece of a tool call's JSON arguments.
///
/// A call without arguments may have no such event at all.
final class ToolCallArgs extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const ToolCallArgs(
    super.json, {
    required this.toolCallId,
    required this.delta,
  });

  /// The id of the call.
  final String toolCallId;

  /// A piece of the JSON-encoded arguments, to append.
  final String delta;
}

/// `TOOL_CALL_END`: a tool call is complete.
final class ToolCallEnd extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const ToolCallEnd(super.json, {required this.toolCallId});

  /// The id of the call.
  final String toolCallId;
}

/// `TOOL_CALL_CHUNK`: a shorthand some backends use instead of start, args
/// and end. The session expands it.
final class ToolCallChunk extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const ToolCallChunk(
    super.json, {
    this.toolCallId,
    this.toolCallName,
    this.parentMessageId,
    this.delta,
  });

  /// The id of the call. Required on the first chunk of a call.
  final String? toolCallId;

  /// The name of the tool. Required on the first chunk of a call.
  final String? toolCallName;

  /// The assistant message the call belongs to.
  final String? parentMessageId;

  /// A piece of the JSON-encoded arguments, to append.
  final String? delta;
}

/// `TOOL_CALL_RESULT`: an agent tool finished on the backend.
///
/// Calls of the app's own tools never get this event; the app answers them
/// with a tool message in the next run.
final class ToolCallResult extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const ToolCallResult(
    super.json, {
    required this.messageId,
    required this.toolCallId,
    required this.content,
  });

  /// The id of the tool message that holds the result.
  final String messageId;

  /// The id of the call.
  final String toolCallId;

  /// The result, usually JSON-encoded.
  final String content;
}

/// `STATE_SNAPSHOT`: the agent's whole state document.
///
/// It replaces the document Tandem keeps. It includes keys the app does not
/// own, such as ag-ui-adk's `_ag_ui_*` keys.
final class StateSnapshot extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const StateSnapshot(super.json, {required this.snapshot});

  /// The document.
  final Map<String, Object?> snapshot;
}

/// `STATE_DELTA`: a change to the agent's state document as an RFC 6902
/// JSON Patch.
final class StateDelta extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const StateDelta(super.json, {required this.operations});

  /// The patch operations (wire key `delta`), such as
  /// `{"op": "replace", "path": "/order/notes", "value": "Urgent"}`.
  final List<Map<String, Object?>> operations;
}

/// `MESSAGES_SNAPSHOT`: the backend's view of the whole history.
///
/// It replaces the history Tandem sends with the next run, not the timeline
/// the user sees.
final class MessagesSnapshot extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const MessagesSnapshot(super.json, {required this.messages});

  /// The history, without messages of roles Tandem does not keep.
  final List<WireMessage> messages;
}

/// Any event Tandem does not act on: an unknown type, a known type without a
/// field Tandem needs, or data an adapter could not read as a JSON object at
/// all (then [json] is empty). The session ignores it.
final class UnknownEvent extends WireEvent {
  /// Creates the event. Usually made by [WireEvent.fromJson].
  const UnknownEvent(super.json, {this.problem});

  /// Why the event could not be decoded; `null` for a well-formed event of
  /// a type Tandem does not know, such as a newer protocol's.
  final String? problem;
}

/// Reads the fields of one event and collects what is missing.
final class _Fields {
  _Fields(Map<String, Object?> json) : _reader = JsonReader(json);

  final JsonReader _reader;

  /// One sentence per field that was missing or of the wrong type.
  final problems = <String>[];

  String required(String key, [String? alternative]) {
    final value = _reader.string(key, alternative);
    if (value == null) {
      problems.add('"$key" is missing or not a string.');
      return '';
    }
    return value;
  }

  String? optional(String key, [String? alternative]) =>
      _reader.string(key, alternative);

  String content(String key) => switch (_reader.value(key)) {
    final String text => text,
    null => _missing(key, ''),
    final other => jsonEncode(other),
  };

  Map<String, Object?> object(String key) =>
      _reader.map(key) ?? _missing(key, const {});

  List<Map<String, Object?>> operations(String key) {
    final list = _reader.list(key);
    final operations = [...?list?.whereType<Map<String, Object?>>()];
    if (list == null || operations.length != list.length) {
      return _missing(key, const []);
    }
    return operations;
  }

  List<WireMessage> messages(String key) {
    final list = _reader.list(key);
    if (list == null) {
      return _missing(key, const []);
    }
    return [
      for (final message in list)
        if (message is Map<String, Object?>) ?WireMessage.fromJson(message),
    ];
  }

  T _missing<T>(String key, T fallback) {
    problems.add('"$key" is missing or of the wrong type.');
    return fallback;
  }
}
