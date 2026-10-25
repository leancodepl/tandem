import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:uuid/uuid.dart';

/// The AG-UI thread of a session: its id and the messages that every run
/// sends again.
final class AgUiThread() {
  var _id = const Uuid().v4();
  final _messages = <AgUiMessage>[];

  /// The user's message of the last [input], until its run goes out.
  AgUiMessage? _outgoing;

  /// The body of the next run, with its [tools] and [context], and
  /// [userText] after the answers. The user's message joins the history only
  /// when the run goes out: [wentOut].
  RunInput input({
    required List<JsonObject> tools,
    required List<JsonObject> context,
    required String? userText,
  }) {
    _outgoing = userText == null ? null : .user(userText);
    return RunInput(
      threadId: _id,
      messages: [..._messages, ?_outgoing],
      tools: tools,
      context: context,
    );
  }

  /// The run of the last [input] went out, with the user's message.
  void wentOut() {
    if (_outgoing case final message?) {
      _messages.add(message);
    }
  }

  /// What the agent sent in [run]: its messages with their calls, and the
  /// results of the calls that ran on the server.
  void addRun(Run run) => _messages.addAll(run.history);

  /// What the agent said in a run that failed. ADK never saw its calls
  /// answered, so they stay out.
  void addFailedRun(Run run) => _messages.addAll(run.assistantTexts);

  /// The answers of [turn], for the next run.
  void addAnswers(Turn turn) => _messages.addAll(turn.answers);

  /// A new thread without the earlier messages, for when what ADK kept of a
  /// run is unknown.
  void startOver() {
    _id = const Uuid().v4();
    _messages.clear();
  }
}
