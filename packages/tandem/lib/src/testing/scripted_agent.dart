import 'dart:async';
import 'dart:collection';
import 'dart:convert';

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

final class const _WaitFor(final Future<void> signal) extends AgentStep;

final class const _Fail(final String message) extends AgentStep;

/// An [AgentConnection] that plays a script in the event shapes of
/// ag-ui-adk, for tests without a model.
///
/// The n-th run plays `turns[n]`; a run beyond the script ends with a
/// `RUN_ERROR`. Events arrive one at a time, asynchronously, so
/// `await pumpEventQueue()` or `pumpAndSettle` plays a whole run.
final class ScriptedAgent(final List<AgentTurn> turns)
    implements AgentConnection {
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
    final ids = {'threadId': input['threadId'], 'runId': input['runId']};
    yield {'type': 'RUN_STARTED', ...ids};
    if (turn >= turns.length) {
      yield {
        'type': 'RUN_ERROR',
        'message': 'The script has no more turns.',
        'code': 'SCRIPT_ENDED',
      };
      return;
    }
    for (final step in turns[turn](input)) {
      switch (step) {
        case _Say(:final text):
          final messageId = 'msg-${++_textMessages}';
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
          final toolCallId = 'call-${++_toolCalls}';
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
          yield {'type': 'RUN_ERROR', 'message': message, 'code': 'SCRIPTED'};
          return;
      }
    }
    yield {'type': 'RUN_FINISHED', ...ids};
  }
}
