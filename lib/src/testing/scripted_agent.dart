import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/json_patch/json_patch.dart';
import 'package:tandem/src/protocol/json_patch/json_pointer.dart';
import 'package:tandem/src/protocol/json_patch/json_value.dart';
import 'package:tandem/src/protocol/wire/events.dart';
import 'package:tandem/src/protocol/wire/messages.dart';
import 'package:tandem/src/protocol/wire/run_input.dart';
import 'package:tandem/src/protocol/wire/wire_conventions.dart';
import 'package:tandem/src/testing/protocol_rules.dart';
import 'package:tandem/src/testing/run_request.dart';

/// What the scripted agent does in one run, given what the app sent.
///
/// Inside a turn, `expect` on the [RunRequest]: a turn that throws fails the
/// test (the error is reported to the current zone, as an uncaught error is)
/// and ends its run with a stream error.
///
/// In a widget test, start the run with a tester action such as
/// `tester.tap`. When the test body starts the run itself
/// (`unawaited(cubit.send(...))`, then `tester.pumpAndSettle()`), an
/// `expect` inside the turn fails with a guarded function conflict; check
/// `agent.requests` after the run instead.
typedef AgentTurn = List<AgentStep> Function(RunRequest request);

/// An in-memory [AgentConnection] that plays one [AgentTurn] per run, with no
/// network. For tests of a screen's integration with the agent.
///
/// With `mimicAdk` (the default) it behaves like ag-ui-adk 0.9.0, so a test
/// sees the same event shapes as production:
/// - `RUN_STARTED` carries `protocolVersion`;
/// - tool calls have no `parentMessageId`, and a call with empty arguments
///   has no `TOOL_CALL_ARGS`;
/// - agent tools end with a `TOOL_CALL_RESULT` whose content is a JSON
///   object (any other result is wrapped as `{"result": ...}`);
/// - state changes arrive as `add` operations of whole top-level values,
///   so [AgentStep.patchState] is applied to the agent's document and sent
///   in that shape;
/// - every run ends with a `STATE_SNAPSHOT` that includes the backend's own
///   keys (`_ag_ui_thread_id`, `_ag_ui_app_name`, `_ag_ui_user_id` and,
///   once a tool of the app was called, a stale `pending_tool_calls`); in a
///   run that called the app's tools, it arrives before their
///   `TOOL_CALL_END`s;
/// - the app's `state` is merged into the agent's document shallowly, one
///   top-level key at a time, at the start of every run.
///
/// Without `mimicAdk` it behaves like a plain AG-UI backend: tool calls have
/// a `parentMessageId`, arguments arrive in pieces, state steps are sent as
/// given, and there is no backend document.
///
/// With `checkProtocol` (the default) every request is checked against the
/// rules Tandem keeps: the same thread id in every run, a new run id, one run
/// at a time, `tools` always present, no backend keys in `state`, no message
/// with the id of a tool call, every call of the app's tools answered before
/// or together with the next user message, and the whole history, including
/// everything the agent sent in the previous run. A request that breaks a
/// rule gets only `RUN_ERROR` with code `PROTOCOL_VIOLATION` and a message
/// that names each broken rule; its turn is not played. ag-ui-adk drops some
/// of these requests silently instead. A run beyond the script gets
/// `RUN_ERROR` with code `SCRIPT_EXHAUSTED`. Both show up as
/// `TandemView.error`.
///
/// Events are sent one per microtask, with no timers, so
/// `await tester.pumpAndSettle()` or `await pumpEventQueue()` drains a run
/// and its automatic follow-ups. Use one agent per session.
///
/// ```dart
/// final agent = ScriptedAgent([
///   (request) => [
///     const AgentStep.say('Looking for HDMI cables.'),
///     const AgentStep.callTool('search_catalog', {'query': 'HDMI 2m'}),
///   ],
///   (request) {
///     expect(request.resultOf('search_catalog')?['status'], 'ok');
///     return [const AgentStep.say('Found two.')];
///   },
/// ]);
/// ```
final class ScriptedAgent implements AgentConnection {
  /// Plays [turns] in order, one per run.
  ScriptedAgent(
    List<AgentTurn> turns, {
    bool mimicAdk = true,
    bool checkProtocol = true,
  }) : _turns = List.of(turns),
       _mimicAdk = mimicAdk,
       _checkProtocol = checkProtocol;

  static const _protocolViolation = 'PROTOCOL_VIOLATION';
  static const _scriptExhausted = 'SCRIPT_EXHAUSTED';
  static const _appName = 'scripted_agent';

  final List<AgentTurn> _turns;
  final bool _mimicAdk;
  final bool _checkProtocol;
  final _requests = <RunRequest>[];
  final _rules = ProtocolRules();
  final _streaming = <_ScriptedRun>{};
  final _idCounters = <String, int>{};
  var _played = 0;
  RunInput? _lastAccepted;

  /// The backend's state document, with `mimicAdk` only.
  Map<String, Object?>? _document;

  /// Every request so far, oldest first, including the ones that broke the
  /// protocol.
  List<RunRequest> get requests => UnmodifiableListView(_requests);

  /// Whether every turn has been played.
  bool get isExhausted => _played >= _turns.length;

  @override
  Stream<WireEvent> run(RunInput input) => _ScriptedRun(this, input).events;

  String _nextId(String prefix) {
    final count = (_idCounters[prefix] ?? 0) + 1;
    _idCounters[prefix] = count;
    return '$prefix-$count';
  }

  /// Takes [input] as the next run: what later requests must keep, and with
  /// `mimicAdk` the merge of its state into the backend's document.
  void _accept(RunInput input) {
    _lastAccepted = input;
    _rules.accepted(input);
    if (!_mimicAdk) {
      return;
    }
    final isFirstRun = _document == null;
    final document = _document ??= {};
    for (final MapEntry(:key, :value) in input.state.entries) {
      // ag-ui-adk ignores the `_ag_ui_*` keys a client sends, but not
      // `pending_tool_calls`.
      if (!key.startsWith(WireConventions.serverKeyPrefix)) {
        document[key] = copyJson(value);
      }
    }
    if (isFirstRun) {
      document['_ag_ui_thread_id'] = input.threadId;
      document['_ag_ui_app_name'] = _appName;
      // ag-ui-adk's default user id.
      document['_ag_ui_user_id'] = 'thread_user_${input.threadId}';
    }
    final pending = document[WireConventions.pendingToolCallsKey];
    if (pending is List<Object?>) {
      final answered = {
        for (final message in input.messages)
          if (message is WireToolMessage) message.toolCallId,
      };
      document[WireConventions.pendingToolCallsKey] = [
        for (final id in pending)
          if (!answered.contains(id)) id,
      ];
    }
  }

  /// Records the app's tools called in a run as open, after that run's
  /// final snapshot, as ag-ui-adk does.
  void _addPendingToolCalls(List<String> toolCallIds) {
    final document = _document;
    if (document == null || toolCallIds.isEmpty) {
      return;
    }
    final pending = document[WireConventions.pendingToolCallsKey];
    document[WireConventions.pendingToolCallsKey] = [
      if (pending is List<Object?>) ...pending,
      ...toolCallIds,
    ];
  }
}

/// One thing the scripted agent does in a run.
///
/// `RUN_STARTED` and `RUN_FINISHED` are added around the steps of a turn;
/// after [AgentStep.fail] the run ends there.
final class AgentStep {
  const AgentStep._();

  /// Streams [text] as one agent message, in a few pieces.
  const factory AgentStep.say(String text) = _Say;

  /// Runs an agent tool on the agent's side: the call with [args], then a
  /// `TOOL_CALL_RESULT` with [result]. The app only sees its activity.
  const factory AgentStep.runAgentTool(
    String name, {
    Map<String, Object?> args,
    Object? result,
  }) = _RunAgentTool;

  /// Calls one of the app's tools with [args] and leaves the call open, as a
  /// real agent does; the app answers it in the next run.
  const factory AgentStep.callTool(String name, [Map<String, Object?> args]) =
      _CallTool;

  /// Replaces the agent's state document with [state] (`STATE_SNAPSHOT`).
  /// With `mimicAdk`, the backend's own keys are added.
  const factory AgentStep.setState(Map<String, Object?> state) = _SetState;

  /// Changes the agent's state document with RFC 6902 [operations]
  /// (`STATE_DELTA`), such as
  /// `[{'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'}]`.
  ///
  /// With `mimicAdk`, the operations are applied to the agent's document and
  /// sent as ag-ui-adk sends state changes: one `add` of the whole new value
  /// for every top-level key they touch (`null` for a removed key, which
  /// ag-ui-adk cannot delete). Operations that do not apply fail the test;
  /// send such a patch with `mimicAdk: false` or [AgentStep.event].
  const factory AgentStep.patchState(List<Map<String, Object?>> operations) =
      _PatchState;

  /// Pauses the run until [signal] completes, for example to let the test
  /// type while a run is in progress.
  ///
  /// When [signal] completes with an error, the run ends with that error as
  /// a stream error, as when the connection breaks.
  const factory AgentStep.waitFor(Future<void> signal) = _WaitFor;

  /// Ends the run with `RUN_ERROR` carrying [message] and [code].
  const factory AgentStep.fail(String message, {String? code}) = _Fail;

  /// Sends [json] as one event, exactly as given, including unknown types.
  ///
  /// A `RUN_FINISHED` or `RUN_ERROR` ends the run there.
  const factory AgentStep.event(Map<String, Object?> json) = _Event;
}

final class _Say extends AgentStep {
  const _Say(this.text) : super._();

  final String text;

  @override
  String toString() => 'AgentStep.say($text)';
}

final class _RunAgentTool extends AgentStep {
  const _RunAgentTool(this.name, {this.args = const {}, this.result})
    : super._();

  final String name;
  final Map<String, Object?> args;
  final Object? result;

  @override
  String toString() => 'AgentStep.runAgentTool($name, $args, $result)';
}

final class _CallTool extends AgentStep {
  const _CallTool(this.name, [this.args = const {}]) : super._();

  final String name;
  final Map<String, Object?> args;

  @override
  String toString() => 'AgentStep.callTool($name, $args)';
}

final class _SetState extends AgentStep {
  const _SetState(this.state) : super._();

  final Map<String, Object?> state;

  @override
  String toString() => 'AgentStep.setState($state)';
}

final class _PatchState extends AgentStep {
  const _PatchState(this.operations) : super._();

  final List<Map<String, Object?>> operations;

  @override
  String toString() => 'AgentStep.patchState($operations)';
}

final class _WaitFor extends AgentStep {
  const _WaitFor(this.signal) : super._();

  final Future<void> signal;

  @override
  String toString() => 'AgentStep.waitFor($signal)';
}

final class _Fail extends AgentStep {
  const _Fail(this.message, {this.code}) : super._();

  final String message;
  final String? code;

  @override
  String toString() => 'AgentStep.fail($message, $code)';
}

final class _Event extends AgentStep {
  const _Event(this.json) : super._();

  final Map<String, Object?> json;

  @override
  String toString() => 'AgentStep.event($json)';
}

/// One run of a [ScriptedAgent]: checks the request, plays the turn and
/// streams its events, one per microtask.
///
/// The stream controller is synchronous, so an event added while the
/// subscription is active has reached the app when `add` returns. That is
/// how the agent knows exactly what the app received, also when the app
/// stops the run.
final class _ScriptedRun {
  _ScriptedRun(this._agent, this._input) {
    _controller = StreamController<WireEvent>(
      sync: true,
      onListen: _onListen,
      onResume: _onResume,
      onCancel: _onCancel,
    );
  }

  final ScriptedAgent _agent;
  final RunInput _input;
  late final StreamController<WireEvent> _controller;

  /// Whether the run was accepted, so what the app receives counts as the
  /// history the next request must carry.
  var _isAccepted = false;

  /// Whether nothing more may be sent: the run ended or was cancelled.
  var _isOver = false;

  Completer<void>? _resumed;

  /// The `TOOL_CALL_END`s of the app's tools, which ag-ui-adk sends after
  /// the run's final snapshot.
  final _deferredEnds = <Map<String, Object?>>[];
  final _appToolCallIds = <String>[];

  /// Without `mimicAdk`: the assistant message the next tool call belongs
  /// to.
  String? _parentMessageId;

  Stream<WireEvent> get events => _controller.stream;

  bool get _mimicAdk => _agent._mimicAdk;

  void _onListen() {
    final busyRun = _agent._streaming.firstOrNull;
    _agent._streaming.add(this);
    unawaited(_play(busyRunId: busyRun?._input.runId));
  }

  void _onResume() {
    final resumed = _resumed;
    _resumed = null;
    resumed?.complete();
  }

  void _onCancel() {
    _end();
    _onResume();
  }

  void _end() {
    _isOver = true;
    _agent._streaming.remove(this);
  }

  Future<void> _play({required String? busyRunId}) async {
    final agent = _agent;
    final request = RunRequest(_input, previous: agent._lastAccepted);
    agent._requests.add(request);
    final violations = agent._checkProtocol
        ? agent._rules.check(_input, busyRunId: busyRunId)
        : const <String>[];
    agent._rules.sawRequest(_input);
    if (violations.isNotEmpty) {
      await _send(
        _runError(
          'Run "${_input.runId}" broke the AG-UI protocol: '
          '${violations.join(' ')}',
          code: ScriptedAgent._protocolViolation,
        ),
      );
      return;
    }
    agent._accept(_input);
    _isAccepted = true;
    if (agent.isExhausted) {
      if (await _send(_runStarted())) {
        await _send(
          _runError(
            'The script has no turn for run "${_input.runId}": all '
            '${agent._turns.length} turns were played. Add a turn to the '
            'ScriptedAgent.',
            code: ScriptedAgent._scriptExhausted,
          ),
        );
      }
      return;
    }
    await _nextMicrotask();
    if (_isOver) {
      return;
    }
    final turn = agent._turns[agent._played++];
    try {
      final steps = turn(request);
      for (final step in steps.whereType<_WaitFor>()) {
        // A signal may fail before the run reaches it, and that is not an
        // uncaught error: the run handles it when it gets there.
        step.signal.ignore();
      }
      if (!await _send(_runStarted())) {
        return;
      }
      for (final step in steps) {
        if (!await _playStep(step)) {
          return;
        }
      }
      await _finish();
    } catch (err, st) {
      Zone.current.handleUncaughtError(err, st);
      _sendError(err, st);
    }
  }

  /// Plays [step]; `false` when the run is over afterwards.
  Future<bool> _playStep(AgentStep step) {
    switch (step) {
      case _Say(:final text):
        final id = _agent._nextId('msg');
        _parentMessageId = id;
        return _sendAll([
          {'type': 'TEXT_MESSAGE_START', 'messageId': id, 'role': 'assistant'},
          for (final piece in _pieces(text, 3))
            {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': id, 'delta': piece},
          {'type': 'TEXT_MESSAGE_END', 'messageId': id},
        ]);
      case _CallTool(:final name, :final args):
        final id = _agent._nextId('call');
        final end = {'type': 'TOOL_CALL_END', 'toolCallId': id};
        if (_mimicAdk) {
          _deferredEnds.add(end);
          _appToolCallIds.add(id);
        }
        return _sendAll([
          ..._toolCallStart(id, name, args),
          if (!_mimicAdk) end,
        ]);
      case _RunAgentTool(:final name, :final args, :final result):
        final id = _agent._nextId('call');
        return _sendAll([
          ..._toolCallStart(id, name, args),
          {'type': 'TOOL_CALL_END', 'toolCallId': id},
          {
            'type': 'TOOL_CALL_RESULT',
            'messageId': _agent._nextId('result'),
            'toolCallId': id,
            'content': _mimicAdk
                // ADK hands a tool's result to the model as an object, so it
                // wraps anything else.
                ? jsonEncode(
                    result is Map<String, Object?>
                        ? result
                        : {'result': result},
                  )
                : (result is String ? result : jsonEncode(result)),
            if (!_mimicAdk) 'role': 'tool',
          },
        ]);
      case _SetState(:final state):
        return _setState(state);
      case _PatchState(:final operations):
        return _patchState(operations);
      case _WaitFor(:final signal):
        return _waitFor(signal);
      case _Fail(:final message, :final code):
        return _sendAll([_runError(message, code: code)]);
      case _Event(:final json):
        return _send(copyJsonObject(json));
    }
    // AgentStep's only constructor is private, and every factory makes one
    // of the steps above.
    throw StateError('Unknown step $step.');
  }

  /// `TOOL_CALL_START` and the `TOOL_CALL_ARGS` of one call.
  List<Map<String, Object?>> _toolCallStart(
    String id,
    String name,
    Map<String, Object?> args,
  ) {
    final arguments = jsonEncode(args);
    return [
      {
        'type': 'TOOL_CALL_START',
        'toolCallId': id,
        'toolCallName': name,
        if (!_mimicAdk)
          'parentMessageId': _parentMessageId ??= _agent._nextId('msg'),
      },
      // ag-ui-adk sends the arguments in one piece, and none when they are
      // empty.
      if (_mimicAdk && args.isNotEmpty)
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': id, 'delta': arguments},
      if (!_mimicAdk)
        for (final piece in _pieces(arguments, 2))
          {'type': 'TOOL_CALL_ARGS', 'toolCallId': id, 'delta': piece},
    ];
  }

  Future<bool> _waitFor(Future<void> signal) async {
    try {
      await signal;
    } catch (err, st) {
      _sendError(err, st);
      return false;
    }
    return !_isOver;
  }

  Future<bool> _setState(Map<String, Object?> state) {
    final document = _agent._document;
    if (!_mimicAdk || document == null) {
      return _send({
        'type': 'STATE_SNAPSHOT',
        'snapshot': copyJsonObject(state),
      });
    }
    final replaced = <String, Object?>{
      ...copyJsonObject(state),
      for (final MapEntry(:key, :value) in document.entries)
        if (WireConventions.isServerKey(key) && !state.containsKey(key))
          key: value,
    };
    _agent._document = replaced;
    return _send({
      'type': 'STATE_SNAPSHOT',
      'snapshot': copyJsonObject(replaced),
    });
  }

  Future<bool> _patchState(List<Map<String, Object?>> operations) {
    final document = _agent._document;
    if (!_mimicAdk || document == null) {
      return _send({
        'type': 'STATE_DELTA',
        'delta': [
          for (final operation in operations) copyJsonObject(operation),
        ],
      });
    }
    final Map<String, Object?> patched;
    try {
      patched = applyJsonPatch(document, operations);
    } on JsonPatchException catch (err) {
      throw StateError(
        'AgentStep.patchState($operations) does not apply to the document '
        'of the agent, ${jsonEncode(document)}: ${err.message}. With '
        'mimicAdk the scripted agent applies patches itself; send a patch '
        'that fails with mimicAdk: false or AgentStep.event.',
      );
    }
    final touched = _touchedKeys(operations, document, patched);
    _agent._document = {
      ...patched,
      for (final key in touched)
        if (!patched.containsKey(key)) key: null,
    };
    if (touched.isEmpty) {
      return Future.value(true);
    }
    return _send({
      'type': 'STATE_DELTA',
      'delta': [
        for (final key in touched)
          {
            'op': 'add',
            'path': formatJsonPointer([key]),
            'value': copyJson(patched[key]),
          },
      ],
    });
  }

  /// With `mimicAdk`: the final snapshot, the deferred ends of the app's
  /// tool calls, then `RUN_FINISHED`.
  Future<void> _finish() async {
    final document = _agent._document;
    if (_mimicAdk && document != null) {
      if (!await _send({
        'type': 'STATE_SNAPSHOT',
        'snapshot': copyJsonObject(document),
      })) {
        return;
      }
      _agent._addPendingToolCalls(_appToolCallIds);
    }
    await _sendAll([
      ..._deferredEnds,
      {
        'type': 'RUN_FINISHED',
        'threadId': _input.threadId,
        'runId': _input.runId,
      },
    ]);
  }

  /// Sends one event in a microtask of its own; `false` when the run is
  /// over afterwards.
  Future<bool> _send(Map<String, Object?> json) async {
    await _nextMicrotask();
    while (_controller.isPaused && !_isOver) {
      await (_resumed ??= Completer<void>()).future;
    }
    if (_isOver) {
      return false;
    }
    final event = WireEvent.fromJson(json);
    final isLast = event is RunFinished || event is RunError;
    if (isLast) {
      // Before the app sees the event, so it may start the next run at once.
      _end();
    }
    if (_isAccepted) {
      _agent._rules.delivered(event);
    }
    _controller.add(event);
    if (isLast) {
      unawaited(_controller.close());
    }
    return !_isOver;
  }

  /// Sends [events] one by one; `false` when the run is over afterwards.
  Future<bool> _sendAll(List<Map<String, Object?>> events) async {
    for (final event in events) {
      if (!await _send(event)) {
        return false;
      }
    }
    return true;
  }

  void _sendError(Object error, StackTrace stackTrace) {
    if (_isOver) {
      return;
    }
    _end();
    _controller.addError(error, stackTrace);
    unawaited(_controller.close());
  }

  Map<String, Object?> _runStarted() => {
    'type': 'RUN_STARTED',
    'threadId': _input.threadId,
    'runId': _input.runId,
    if (_mimicAdk) 'protocolVersion': '1.0',
  };

  static Map<String, Object?> _runError(String message, {String? code}) => {
    'type': 'RUN_ERROR',
    'message': message,
    'code': ?code,
  };

  static Future<void> _nextMicrotask() => Future<void>.value();

  /// The top-level keys that [operations] write, in the order they are
  /// first written.
  static Set<String> _touchedKeys(
    List<Map<String, Object?>> operations,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) {
    final keys = <String>{};
    for (final operation in operations) {
      final op = operation['op'];
      if (op == 'test') {
        continue;
      }
      for (final field in ['path', if (op == 'move') 'from']) {
        final pointer = operation[field];
        if (pointer is! String) {
          continue;
        }
        final tokens = parseJsonPointer(pointer);
        if (tokens.isEmpty) {
          keys
            ..addAll(before.keys)
            ..addAll(after.keys);
        } else {
          keys.add(tokens.first);
        }
      }
    }
    return keys;
  }

  /// [text] in at most [count] pieces of about the same length, never
  /// splitting a surrogate pair. Empty for an empty [text].
  static List<String> _pieces(String text, int count) {
    final pieces = <String>[];
    var start = 0;
    for (var piece = 1; piece < count; piece++) {
      var end = text.length * piece ~/ count;
      if (end > 0 && end < text.length && _isLowSurrogate(text, end)) {
        end++;
      }
      if (end > start && end < text.length) {
        pieces.add(text.substring(start, end));
        start = end;
      }
    }
    if (start < text.length) {
      pieces.add(text.substring(start));
    }
    return pieces;
  }

  static bool _isLowSurrogate(String text, int index) =>
      text.codeUnitAt(index) & 0xFC00 == 0xDC00;
}
