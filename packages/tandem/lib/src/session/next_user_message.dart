import 'package:tandem/src/protocol/run_input.dart';

/// What the user wrote since the last run went out, after the notes for the
/// agent. It goes to the agent as one message, the texts joined by a blank
/// line: ag-ui-adk passes the model only the last new user message of a run.
final class NextUserMessage() {
  final _notes = <String>[];
  final _texts = <String>[];

  /// Throws an [ArgumentError] when [text] is blank.
  void add(String text) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be blank');
    }
    _texts.add(text);
  }

  /// [text] goes before what the user wrote.
  void addNote(String text) => _notes.add(text);

  /// The message for the next run, or null when there is nothing to send. A
  /// text goes out with one run only.
  AgUiMessage? take() {
    final said = [..._notes, ..._texts];
    if (said.isEmpty) {
      return null;
    }
    _notes.clear();
    _texts.clear();
    return AgUiMessage.user(said.join('\n\n'));
  }

  /// Drops what the user wrote. The notes stay.
  void clear() => _texts.clear();
}
