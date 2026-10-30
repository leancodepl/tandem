/// The text of the run's last message when the user sent it, or empty.
String lastUserText(Map<String, Object?> raw) => switch (raw['messages']) {
  [..., {'role': 'user', 'content': final String text}] => text,
  _ => '',
};
