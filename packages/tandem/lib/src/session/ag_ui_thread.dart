import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:uuid/uuid.dart';

/// The AG-UI thread of a session: its id and the messages that every run
/// sends again.
final class AgUiThread() {
  var _id = const Uuid().v4();
  final _messages = <JsonObject>[];

  /// The body of the next run, with what [listing] shares with the agent.
  JsonObject input(AgentListing listing) => runInput(
    threadId: _id,
    runId: const Uuid().v4(),
    messages: [..._messages],
    listing: listing,
  );

  /// What the agent said in [run], and the calls of its [turn].
  void addTurn(Run run, Turn turn) => _messages.addAll([
    ...run.assistantTexts,
    for (final call in turn.calls)
      assistantToolCall(call.id, call.tool, call.argumentsJson),
  ]);

  /// What the agent said in a run that failed. ADK never saw its calls
  /// answered, so they stay out.
  void addFailedRun(Run run) => _messages.addAll(run.assistantTexts);

  /// The answers of [turn], then the user's [text].
  void addAnswers(Turn turn, String? text) => _messages.addAll([
    ...turn.answers,
    if (text case final message?) userMessage(const Uuid().v4(), message),
  ]);

  /// A new thread without the earlier messages, for when what ADK kept of a
  /// run is unknown.
  void startOver() {
    _id = const Uuid().v4();
    _messages.clear();
  }
}
