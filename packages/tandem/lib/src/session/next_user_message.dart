import 'package:tandem/src/protocol/run_input.dart';

/// What the user wrote since the last run went out. It goes to the agent as
/// one message, the texts joined by a blank line: ag-ui-adk passes the model
/// only the last new user message of a run.
final class NextUserMessage() {
  final _texts = <String>[];

  /// Throws an [ArgumentError] when [text] is blank.
  void add(String text) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be blank');
    }
    _texts.add(text);
  }

  /// The message for the next run, or null when the user wrote nothing.
  AgUiMessage? get message =>
      _texts.isEmpty ? null : AgUiMessage.user(_texts.join('\n\n'));

  /// The message went out with a run.
  void clear() => _texts.clear();
}
