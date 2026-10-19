import 'dart:convert';

/// What the gallery's scripted agents read from the body of a run.
extension DemoRequest on Map<String, Object?> {
  List<Map<String, Object?>> get _messages => switch (this) {
    {'messages': final List<Object?> messages} => messages.cast(),
    _ => const [],
  };

  bool get isUser => _messages.lastOrNull?['role'] == 'user';

  /// The decoded value of the screen's only `.sees`.
  Object? get view => switch (this) {
    {'context': [{'value': final String value}]} => jsonDecode(value),
    _ => null,
  };

  bool lists(String tool) => switch (this) {
    {'tools': final List<Object?> tools} => tools.any(
      (listed) => listed is Map && listed['name'] == tool,
    ),
    _ => false,
  };

  /// The method that the last message answers.
  String? get lastTool {
    final answered = _messages.lastOrNull?['toolCallId'];

    return [
      for (final message in _messages)
        if (message['toolCalls'] case final List<Object?> calls)
          for (final call in calls)
            if (call
                case {'id': final id, 'function': {'name': final String name}}
                when id == answered)
              name,
    ].lastOrNull;
  }

  Object? get lastResult => switch (_messages.lastOrNull) {
    {'role': 'tool', 'content': final String content} => jsonDecode(content),
    _ => null,
  };

  /// What kept a call of the last turn from running, in the agent's words.
  String? get problem => [
    for (final answer in _messages.reversed.takeWhile(_isAnswer))
      if (answer case {'content': final String content})
        if (jsonDecode(content) case {'status': final String status})
          switch (status) {
            'rejected_by_user' => 'You rejected the action. It did not run.',
            'invalidated' =>
              'What I saw changed. Ask again to use the current values.',
            'cancelled' =>
              'The action was cancelled. Ask again when you are ready.',
            _ =>
              'The action did not go through. '
                  'Check the screen before trying again.',
          },
  ].firstOrNull;
}

bool _isAnswer(Map<String, Object?> message) => message['role'] == 'tool';
