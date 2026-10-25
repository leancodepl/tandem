import 'dart:convert';

/// The messages of the body of a run.
List<Map<String, Object?>> messagesOf(Map<String, Object?> body) {
  final {'messages': messages as List<Object?>} = body;
  return messages.cast();
}

/// The value of the app_notes entry of the body of a run, decoded.
Object? appNotesOf(Map<String, Object?> body) {
  final {'context': context as List<Object?>} = body;
  final {'value': value as String} = context.cast<Map<String, Object?>>().last;
  return jsonDecode(value);
}
