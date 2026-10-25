import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/next_user_message.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:uuid/uuid.dart';

/// The AG-UI thread of a session: its id and the messages that every run
/// sends again.
final class AgUiThread() {
  var _id = const Uuid().v4();
  final _messages = <AgUiMessage>[];
  final _nextUserMessage = NextUserMessage();

  /// The body of the next run, with its [tools] and [context].
  RunInput input({
    required List<JsonObject> tools,
    required List<JsonObject> context,
  }) {
    if (_nextUserMessage.take() case final message?) {
      _messages.add(message);
    }
    return RunInput(
      threadId: _id,
      messages: [..._messages],
      tools: tools,
      context: context,
    );
  }

  /// What the agent said in [run], and the calls of its [turn].
  void addTurn(Run run, Turn turn) => _messages.addAll([
    ...run.assistantTexts,
    for (final call in turn.calls)
      AgUiMessage.assistantToolCall(call.id, call.tool, call.argumentsJson),
  ]);

  /// What the agent said in a run that failed. ADK never saw its calls
  /// answered, so they stay out.
  void addFailedRun(Run run) => _messages.addAll(run.assistantTexts);

  /// The answers of [turn], for the next run.
  void addAnswers(Turn turn) => _messages.addAll(turn.answers);

  /// What the user and the app sent, which the next run sends as one message
  /// after the answers.
  void addUserTexts(Iterable<String> texts) =>
      texts.forEach(_nextUserMessage.add);

  /// A new thread without the earlier messages, for when what ADK kept of a
  /// run is unknown.
  void startOver() {
    _id = const Uuid().v4();
    _messages.clear();
    _nextUserMessage.clear();
  }
}
