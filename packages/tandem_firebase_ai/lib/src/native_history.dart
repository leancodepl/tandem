import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:tandem_firebase_ai/src/firebase_failure.dart';
import 'package:tandem_firebase_ai/src/firebase_request.dart';

const nativeHistoryKey = 'tandem_firebase_ai';

List<Content> nativeContents(JsonObject input, {required String source}) {
  final messages = input['messages'];
  if (messages is! List<Object?>) {
    throw FirebaseFailure(
      FirebaseErrorCode.invalidInput,
      'Expected a list of messages.',
    );
  }
  final contents = <Content>[];
  final callIds = <String>{};
  final pending = <String, _HistoryCall>{};
  for (final message in messages) {
    if (message is! JsonObject) {
      throw FirebaseFailure(
        FirebaseErrorCode.invalidInput,
        'Expected a message object.',
      );
    }
    if (message['role'] != 'tool' && pending.isNotEmpty) {
      throw FirebaseFailure(
        FirebaseErrorCode.incompatibleHistory,
        'A tool batch is missing results.',
      );
    }
    switch (message['role']) {
      case 'user':
        final text = _text(message['content']);
        _appendUser(contents, [TextPart(text)]);
      case 'assistant':
        final calls = _calls(message['toolCalls']);
        final text = _text(message['content'] ?? '');
        final native = _nativeContent(message, source, text, calls);
        if (native != null) {
          // Gemini requires a user turn before the tool calls retained by a reset.
          if (contents.isEmpty && calls.isNotEmpty) {
            contents.add(Content.text('The conversation was reset.'));
          }
          contents.add(native);
        } else if (text.isNotEmpty) {
          contents.add(Content.model([TextPart(text)]));
        }
        for (final call in calls) {
          if (callIds.add(call.id)) {
            pending[call.id] = call;
          } else {
            throw FirebaseFailure(
              FirebaseErrorCode.incompatibleHistory,
              'Duplicate tool call in history.',
            );
          }
        }
      case 'tool':
        final call = pending.remove(message['toolCallId']);
        if (call == null) {
          throw FirebaseFailure(
            FirebaseErrorCode.incompatibleHistory,
            'A tool result has no matching call.',
          );
        }
        final text = _text(message['content']);
        Object? result;
        try {
          result = jsonDecode(text);
        } on FormatException {
          result = text;
        }
        final part = FunctionResponse(call.name, {
          'result': result,
        }, id: call.nativeId);
        // A parallel batch needs all its answers in the same user content.
        _appendUser(contents, [part]);
      default:
        throw FirebaseFailure(
          FirebaseErrorCode.invalidInput,
          'Unsupported message role.',
        );
    }
  }
  if (pending.isNotEmpty) {
    throw FirebaseFailure(
      FirebaseErrorCode.incompatibleHistory,
      'A tool batch is missing results.',
    );
  }
  if (contents.isEmpty) {
    throw FirebaseFailure(
      FirebaseErrorCode.invalidInput,
      'The conversation is empty.',
    );
  }
  final context = input['context'] ?? const [];
  if (context is! List<Object?>) {
    throw FirebaseFailure(
      FirebaseErrorCode.invalidInput,
      'Expected a list of context entries.',
    );
  }
  if (context.isNotEmpty) {
    _appendUser(contents, [
      TextPart('Current screen context (JSON data):\n${jsonEncode(context)}'),
    ]);
  }
  return contents;
}

void _appendUser(List<Content> contents, List<Part> parts) {
  if (contents.isNotEmpty && contents.last.role == 'user') {
    contents.last.parts.addAll(parts);
  } else {
    contents.add(Content.multi(parts));
  }
}

Content? _nativeContent(
  JsonObject message,
  String source,
  String text,
  List<_HistoryCall> calls,
) {
  final metadata = message['metadata'];
  final capsule = metadata is JsonObject ? metadata[nativeHistoryKey] : null;
  if (capsule
      case {
        'version': 1,
        'source': final String owner,
        'calls': final List<Object?> callIds,
        'parts': final List<Object?> parts,
      }
      when owner == source) {
    if (_matchParts(parts, text, calls, callIds)) {
      // UnknownPart keeps signatures without using Firebase's test-only constructors.
      return Content.model([
        for (final part in parts.cast<JsonObject>()) UnknownPart(part),
      ]);
    }
  }
  if (calls.isNotEmpty) {
    throw FirebaseFailure(
      FirebaseErrorCode.incompatibleHistory,
      'Native tool history does not match this connection and conversation. Start a new conversation.',
    );
  }
  // Interrupted text has no retained calls and uses exactly what the user saw.
  return null;
}

bool _matchParts(
  List<Object?> parts,
  String text,
  List<_HistoryCall> calls,
  List<Object?> callIds,
) {
  if (callIds.length != calls.length) return false;
  final visible = StringBuffer();
  var callIndex = 0;
  for (final part in parts) {
    switch (part) {
      case {'text': final String value}:
        if (part['thought'] != true) visible.write(value);
      case {'functionCall': final JsonObject function}:
        if (callIndex >= calls.length) return false;
        final call = calls[callIndex];
        if (!call.matchesNative(function, callIds[callIndex])) return false;
        callIndex++;
      default:
        return false;
    }
  }
  return callIndex == calls.length && visible.toString() == text;
}

List<_HistoryCall> _calls(Object? input) {
  if (input == null) return [];
  if (input is! List<Object?>) {
    throw FirebaseFailure(
      FirebaseErrorCode.invalidInput,
      'Expected tool calls.',
    );
  }
  return [
    for (final call in input)
      switch (call) {
        {
          'id': final String id,
          'function': {
            'name': final String name,
            'arguments': final String arguments,
          },
        }
            when id.isNotEmpty && name.isNotEmpty =>
          _HistoryCall(id, name, arguments),
        _ => throw FirebaseFailure(
          FirebaseErrorCode.invalidInput,
          'Invalid tool call in history.',
        ),
      },
  ];
}

String _text(Object? input) => switch (input) {
  final String text => text,
  _ => throw FirebaseFailure(
    FirebaseErrorCode.invalidInput,
    'Only text message content is supported.',
  ),
};

final class _HistoryCall(
  final String id,
  final String name,
  final String arguments,
) {
  String? nativeId;

  bool matchesNative(JsonObject function, Object? ids) {
    if (ids
        case {'id': final String callId, 'nativeId': final String? providerId}
        when callId == id && providerId == function['id']) {
      if (function['args'] case final JsonObject args
          when name == function['name'] && arguments == jsonEncode(args)) {
        nativeId = providerId;
        return true;
      }
    }
    return false;
  }
}
