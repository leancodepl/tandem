import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:tandem/src/ids.dart';
import 'package:tandem/src/protocol/agent_connection.dart';

const _toolCallPrefix = 'call-';
const _failCode = 'SCRIPTED';
const _scriptEndedCode = 'SCRIPT_ENDED';
const _scriptEndedMessage = 'The script has no more turns.';

/// What the agent does in one run, given the request of that run.
typedef AgentTurn = List<AgentStep> Function(Map<String, Object?> request);

/// One thing a [ScriptedAgent] does in a run.
sealed class const AgentStep() {
  /// For the kinds of steps below.
  this;

  /// Says [text] in one text message.
  const factory say(String text) = _Say;

  /// Calls the tool [name] with [arguments].
  const factory callTool(String name, [Map<String, Object?> arguments]) =
      _CallTool;

  /// Sends nothing until [signal] completes.
  const factory waitFor(Future<void> signal) = _WaitFor;

  /// Ends the run with `RUN_ERROR` and [message].
  const factory fail(String message) = _Fail;
}

final class const _Say(final String text) extends AgentStep;

final class const _CallTool(
  final String name, [
  final Map<String, Object?> arguments = const {},
]) extends AgentStep;

final class const _WaitFor(final Future<void> signal) extends AgentStep;

final class const _Fail(final String message) extends AgentStep;

/// An [AgentConnection] that plays a script in the event shapes of
/// ag-ui-adk, for tests and demos without a model.
///
/// The n-th run plays `turns[n]`; a run beyond the script ends with a
/// `RUN_ERROR`. Events arrive one at a time, asynchronously, so
/// `await pumpEventQueue()` or `pumpAndSettle` plays a whole run.
final class ScriptedAgent(final List<AgentTurn> turns)
    implements AgentConnection {
  /// Plays [turns], one per run.
  this;

  final _requests = <Map<String, Object?>>[];
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
    final ids = {'threadId': input['threadId'], 'runId': input['runId']};
    yield {'type': 'RUN_STARTED', ...ids};
    if (turn >= turns.length) {
      yield {
        'type': 'RUN_ERROR',
        'message': _scriptEndedMessage,
        'code': _scriptEndedCode,
      };
      return;
    }
    for (final step in turns[turn](input)) {
      switch (step) {
        case _Say(:final text):
          final messageId = newId();
          yield {
            'type': 'TEXT_MESSAGE_START',
            'messageId': messageId,
            'role': 'assistant',
          };
          yield {
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': messageId,
            'delta': text,
          };
          yield {'type': 'TEXT_MESSAGE_END', 'messageId': messageId};
        case _CallTool(:final name, :final arguments):
          final toolCallId = '$_toolCallPrefix${++_toolCalls}';
          yield {
            'type': 'TOOL_CALL_START',
            'toolCallId': toolCallId,
            'toolCallName': name,
          };
          if (arguments.isNotEmpty) {
            yield {
              'type': 'TOOL_CALL_ARGS',
              'toolCallId': toolCallId,
              'delta': jsonEncode(arguments),
            };
          }
          yield {'type': 'TOOL_CALL_END', 'toolCallId': toolCallId};
        case _WaitFor(:final signal):
          await signal;
        case _Fail(:final message):
          yield {'type': 'RUN_ERROR', 'message': message, 'code': _failCode};
          return;
      }
    }
    yield {'type': 'RUN_FINISHED', ...ids};
  }
}
