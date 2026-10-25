import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/events.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/agent_state.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:uuid/uuid.dart';

/// The AG-UI thread of a `TandemThread`: its id, and the messages and the
/// agent's state that every run sends again.
final class AgUiThread() {
  var _id = const Uuid().v4();
  final _messages = <AgUiMessage>[];
  final agentState = AgentState();

  /// What the screen gave the agent when the last session of the thread let
  /// it go, null for a thread without history.
  SeesSnapshot? get seenAtLeave => _seenAtLeave;
  SeesSnapshot? _seenAtLeave;

  String get id => _id;

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
    agentState.startRun();
    return RunInput(
      threadId: _id,
      messages: [..._messages, ?_outgoing],
      state: agentState.value,
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

  /// What the agent sent in [run]: each message with its text and calls,
  /// then the results of its calls that ran on the backend. A backend call
  /// without a result stays out.
  void addRun(Run run) {
    for (final message in run.sent) {
      final calls = [
        for (final call in message.calls)
          if (call.inApp || call.result != null) call,
      ];
      if (message.text == null && calls.isEmpty) {
        continue;
      }
      _messages
        ..add(
          .assistant(
            message.id,
            text: message.text,
            toolCalls: [
              for (final call in calls)
                AgUiToolCall(call.id, call.tool, call.arguments),
            ],
          ),
        )
        ..addAll([
          for (final call in calls)
            if (call.result case ToolCallResult(
              :final messageId,
              :final content,
            ))
              .toolResult(messageId, call.id, content),
        ]);
    }
  }

  /// What the agent said in a run that failed. ADK never saw its calls
  /// answered, so they stay out.
  void addFailedRun(Run run) => _messages.addAll([
    for (final MapEntry(key: id, value: message) in run.texts.entries)
      .assistant(id, text: message.text),
  ]);

  /// The session that went on with the thread lets it go while the screen
  /// gives the agent [seen].
  void leave(SeesSnapshot seen) =>
      _seenAtLeave = _messages.isEmpty ? null : seen;

  /// The answers of [turn], for the next run.
  void addAnswers(Turn turn) => _messages.addAll(turn.answers);

  /// A new thread without the earlier messages and state, for when what ADK
  /// kept of a run is unknown.
  void startOver() {
    _id = const Uuid().v4();
    _messages.clear();
    agentState.clear();
    _seenAtLeave = null;
  }
}
