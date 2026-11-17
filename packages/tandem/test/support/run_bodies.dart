import 'dart:convert';

/// The messages of the body of a run.
List<Map<String, Object?>> messagesOf(Map<String, Object?> body) {
  final {'messages': messages as List<Object?>} = body;
  return messages.cast();
}

/// The messages of the body of a run, one line each: `role: text`, or the
/// id with the call or the answer.
List<String> linesOf(Map<String, Object?> body) => [
  for (final message in messagesOf(body))
    switch (message) {
      {'role': 'tool', 'id': final id, 'content': final content} =>
        '$id $content',
      {
        'id': final id,
        'toolCalls': [
          {'function': {'name': final name, 'arguments': final arguments}},
        ],
      } =>
        '$id $name $arguments',
      {'role': final role, 'content': final content} => '$role: $content',
      _ => '$message',
    },
];

/// The value of the app_notes entry of the body of a run, decoded.
Object? appNotesOf(Map<String, Object?> body) {
  final {'context': context as List<Object?>} = body;
  final {'value': value as String} = context.cast<Map<String, Object?>>().last;
  return jsonDecode(value);
}
