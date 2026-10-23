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

  /// The body of [run], with what it shares with the agent.
  RunInput input(Run run) {
    if (_nextUserMessage.take() case final message?) {
      _messages.add(message);
    }
    return RunInput(
      threadId: _id,
      messages: [..._messages],
      tools: run.tools,
      context: run.listing.context,
    );
  }

  /// What the agent said in [run], and its calls.
  void addTurn(Run run) => _messages.addAll([
    ...run.assistantTexts,
    for (final call in run.calls.values)
      AgUiMessage.assistantToolCall(call.id, call.tool, call.argumentsJson),
  ]);

  /// What the agent said in a run that failed. ADK never saw its calls
  /// answered, so they stay out.
  void addFailedRun(Run run) => _messages.addAll(run.assistantTexts);

  /// The answers of [turn], then the user's [text].
  void addAnswers(Turn turn, String? text) {
    _messages.addAll(turn.answers);
    if (text case final message?) {
      _nextUserMessage.add(message);
    }
  }

  /// The user's [text], without answers.
  void addMessage(String text) => _nextUserMessage.add(text);

  /// A new thread without the earlier messages, for when what ADK kept of a
  /// run is unknown.
  void startOver() {
    _id = const Uuid().v4();
    _messages.clear();
    _nextUserMessage.clear();
  }
}
