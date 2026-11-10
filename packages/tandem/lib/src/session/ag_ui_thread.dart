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
final class AgUiThread({String? id}) {
  /// The id the app gave, which the thread keeps for good.
  final String? _appId = id;
  var _id = id ?? const Uuid().v4();
  final _messages = <AgUiMessage>[];
  final _unsentCallMessages = <AgUiMessage>[];
  final agentState = AgentState();

  /// What the screen gave the agent when the last session of the thread let
  /// it go, null for a thread without history beyond its unsent calls.
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

  /// The run of the last [input] went out, with the user's message and
  /// any buffered tool answers.
  void wentOut() {
    _unsentCallMessages.clear();
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
      final messages = <AgUiMessage>[
        .assistant(
          message.id,
          text: message.text,
          toolCalls: [
            for (final call in calls)
              AgUiToolCall(call.id, call.tool, call.arguments),
          ],
        ),
        for (final call in calls)
          if (call.result case ToolCallResult(:final messageId, :final content))
            .toolResult(messageId, call.id, content),
      ];
      _messages.addAll(messages);
      if (_appId != null && calls.any((call) => call.inApp)) {
        _unsentCallMessages.addAll(messages);
      }
    }
  }

  /// What the agent said in a run that failed. ADK never saw its calls
  /// answered, so they stay out.
  void addFailedRun(Run run) => _messages.addAll([
    for (final MapEntry(key: id, value: message) in run.texts.entries)
      .assistant(id, text: message.text),
  ]);

  /// The session that went on with the thread lets it go while the screen
  /// gives the agent [seen]. The unsent calls are part of the history, and
  /// alone they do not tie the thread to [seen].
  void leave(SeesSnapshot seen) => _seenAtLeave =
      _messages.length > _unsentCallMessages.length ? seen : null;

  /// The answers of [turn], for the next run.
  void addAnswers(Turn turn) {
    final answers = turn.answers;
    _messages.addAll(answers);
    if (_appId != null) {
      _unsentCallMessages.addAll(answers);
    }
  }

  /// Clears the local history and state. An app ID stays. Set
  /// [keepUnsentCalls] after closing a known turn to keep its calls and
  /// answers for the next run under that ID.
  void startOver({bool keepUnsentCalls = false}) {
    _id = _appId ?? const Uuid().v4();
    _messages.clear();
    if (keepUnsentCalls) {
      _messages.addAll(_unsentCallMessages);
    } else {
      _unsentCallMessages.clear();
    }
    agentState.clear();
    _seenAtLeave = null;
  }
}
