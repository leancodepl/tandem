import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/agent_connection.dart';

/// What the agent does in one run of a [ScriptedAgent], given the body of
/// the run.
typedef AgentTurn = List<AgentStep> Function(Map<String, Object?> request);

/// One step of an [AgentTurn].
sealed class const AgentStep() {
  /// Streams [text] as one message of the agent.
  const factory say(String text) = _Say;

  /// Calls the app's method [name], in snake_case, with [arguments]. The
  /// session runs it when the run ends.
  const factory callTool(String name, [Map<String, Object?> arguments]) =
      _CallTool;

  /// Sends the agent's whole state, `session.agentState`, as
  /// `STATE_SNAPSHOT`.
  const factory stateSnapshot(Map<String, Object?> snapshot) = _StateSnapshot;

  /// Changes the agent's state with the JSON Patch operations of [delta], as
  /// `STATE_DELTA`.
  const factory stateDelta(List<Map<String, Object?>> delta) = _StateDelta;

  /// Waits for [signal] before the next step, such as to keep a run open
  /// in a test.
  const factory waitFor(Future<void> signal) = _WaitFor;

  /// Ends the run with `RUN_ERROR` and [message].
  const factory fail(String message) = _Fail;
}

final class const _Say(final String text) extends AgentStep;

final class const _CallTool(
  final String name, [
  final Map<String, Object?> arguments = const {},
]) extends AgentStep;

final class const _StateSnapshot(final Map<String, Object?> snapshot)
    extends AgentStep;

final class const _StateDelta(final List<Map<String, Object?>> delta)
    extends AgentStep;

final class const _WaitFor(final Future<void> signal) extends AgentStep;

final class const _Fail(final String message) extends AgentStep;

/// The codes a [ScriptedAgent] fails its runs with.
extension type const ScriptedErrorCode._(String value) implements RunErrorCode {
  /// An [AgentStep.fail] step failed the run.
  static const scripted = ScriptedErrorCode._('SCRIPTED');

  /// The script had no turn left for the run.
  static const scriptEnded = ScriptedErrorCode._('SCRIPT_ENDED');
}

/// An [AgentConnection] that plays a script in the event shapes of
/// ag-ui-adk, for tests without a model.
///
/// The n-th run plays `turns[n]`; a run beyond the script ends with a
/// `RUN_ERROR`. [ScriptedAgent.repeating] reuses one turn for every run.
/// Events arrive one at a time, asynchronously, so
/// `await pumpEventQueue()` or `pumpAndSettle` plays a whole run.
final class ScriptedAgent._(
  final List<AgentTurn> turns,
  final AgentTurn? _repeatedTurn,
) implements AgentConnection {
  new(List<AgentTurn> turns) : this._(turns, null);

  /// Plays [turn] on every run, with that run's raw request body.
  new repeating(AgentTurn turn) : this._(const [], turn);

  final _requests = <Map<String, Object?>>[];
  var _textMessages = 0;
  var _toolCalls = 0;

  /// The body of every run so far, oldest first.
  List<Map<String, Object?>> get requests => UnmodifiableListView(_requests);

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    _requests.add(input);
    return _play(_requests.length - 1, input);
  }

  Stream<Map<String, Object?>> _play(
    int turn,
    Map<String, Object?> input,
  ) async* {
    final ids = {
      AgUiFields.threadId: input[AgUiFields.threadId],
      AgUiFields.runId: input[AgUiFields.runId],
    };
    yield {AgUiFields.type: AgUiEventTypes.runStarted, ...ids};
    final callback = _repeatedTurn ?? turns.elementAtOrNull(turn);
    if (callback == null) {
      yield {
        AgUiFields.type: AgUiEventTypes.runError,
        AgUiFields.message: 'The script has no more turns.',
        AgUiFields.code: ScriptedErrorCode.scriptEnded,
      };
      return;
    }
    for (final step in callback(input)) {
      switch (step) {
        case _Say(:final text):
          final messageId = 'msg-${++_textMessages}';
          yield {
            AgUiFields.type: AgUiEventTypes.textMessageStart,
            AgUiFields.messageId: messageId,
            AgUiFields.role: AgUiMessageRoles.assistant,
          };
          yield {
            AgUiFields.type: AgUiEventTypes.textMessageContent,
            AgUiFields.messageId: messageId,
            AgUiFields.delta: text,
          };
          yield {
            AgUiFields.type: AgUiEventTypes.textMessageEnd,
            AgUiFields.messageId: messageId,
          };
        case _CallTool(:final name, :final arguments):
          final toolCallId = 'call-${++_toolCalls}';
          yield {
            AgUiFields.type: AgUiEventTypes.toolCallStart,
            AgUiFields.toolCallId: toolCallId,
            AgUiFields.toolCallName: name,
          };
          if (arguments.isNotEmpty) {
            yield {
              AgUiFields.type: AgUiEventTypes.toolCallArgs,
              AgUiFields.toolCallId: toolCallId,
              AgUiFields.delta: jsonEncode(arguments),
            };
          }
          yield {
            AgUiFields.type: AgUiEventTypes.toolCallEnd,
            AgUiFields.toolCallId: toolCallId,
          };
        case _StateSnapshot(:final snapshot):
          yield {
            AgUiFields.type: AgUiEventTypes.stateSnapshot,
            AgUiFields.snapshot: snapshot,
          };
        case _StateDelta(:final delta):
          yield {
            AgUiFields.type: AgUiEventTypes.stateDelta,
            AgUiFields.delta: delta,
          };
        case _WaitFor(:final signal):
          await signal;
        case _Fail(:final message):
          yield {
            AgUiFields.type: AgUiEventTypes.runError,
            AgUiFields.message: message,
            AgUiFields.code: ScriptedErrorCode.scripted,
          };
          return;
      }
    }
    yield {AgUiFields.type: AgUiEventTypes.runFinished, ...ids};
  }
}
