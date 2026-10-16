import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/json_patch/json_value.dart';
import 'package:tandem/src/protocol/wire/events.dart';
import 'package:tandem/src/protocol/wire/messages.dart';
import 'package:tandem/src/protocol/wire/run_input.dart';
import 'package:tandem/src/protocol/wire/wire_conventions.dart';
import 'package:tandem/src/session/history.dart';
import 'package:tandem/src/session/ids.dart';
import 'package:tandem/src/session/shared_state.dart';
import 'package:tandem/src/session/tandem_options.dart';
import 'package:tandem/src/state/state_codec.dart';
import 'package:tandem/src/state/state_host.dart';
import 'package:tandem/src/tools/tool.dart';
import 'package:tandem/src/tools/tool_args.dart';
import 'package:tandem/src/view/tandem_error.dart';
import 'package:tandem/src/view/tandem_view.dart';
import 'package:tandem/src/view/timeline.dart';

/// One session with the agent for one screen.
///
/// The agent and the user work on the same shared state: the agent's state
/// changes are written into [StateHost], the user's edits are reported back
/// to the agent, the agent calls the screen's [Tool]s, and tools with
/// [Tool.needsApproval] wait for the user.
///
/// In AG-UI terms, a session is a thread and every [send] starts a run: one
/// request to the agent backend that streams events back. When the agent
/// calls the app's tools, the session runs them and starts follow-up runs on
/// its own until the agent is done.
///
/// The whole surface is [send], [stop], [dispose], [view] and [views];
/// approvals and retries are actions on the items of [view]
/// ([ApprovalRequest.approve], [TandemError.retry]). With `tandem_bloc`,
/// `TandemScope` creates the session. In plain Dart:
///
/// ```dart
/// final session = TandemSession(
///   connection: AgentConnection.http(Uri.parse('http://127.0.0.1:8000/agent')),
///   host: StateHost.memory(OrderDraft.empty),
///   codec: StateCodec.json('order', OrderDraft.fromJson,
///       toJson: (draft) => draft.toJson()),
///   tools: [searchCatalog, placeOrder],
/// );
/// await session.send('40 HDMI cables 2m for Acme, delivery Friday');
/// ```
///
/// How the shared state is kept in sync:
/// - Conflicts are resolved per leaf, last write wins. A change of the agent
///   is only what differs from what the agent already knew (the state sent
///   at the start of the run and its own earlier changes), so the agent
///   restating the state at the end of a run does not undo what the user
///   typed during the run. A list whose length changed is taken as a whole.
/// - The user's edits are told from the session's own writes by content.
///   An edit clears the [TandemView.marks] of the edited fields, makes
///   pending approval requests stale and, with
///   [TandemOptions.reportUserEdits], is listed in the next run.
final class TandemSession<S> {
  /// Creates the session and starts listening to [host]. Nothing is sent
  /// until the first [send].
  ///
  /// Throws an [ArgumentError] when two [tools] share a name or a name does
  /// not match `[a-zA-Z0-9_-]{1,64}`.
  TandemSession({
    required AgentConnection connection,
    required StateHost<S> host,
    required StateCodec<S> codec,
    List<Tool<S>> tools = const [],
    TandemOptions options = const TandemOptions(),
  }) : _connection = connection,
       _host = host,
       _options = options,
       _tools = _toolsByName(tools),
       threadId = options.threadId ?? newUuid() {
    _wireTools = [
      for (final tool in _tools.values)
        WireTool(
          name: tool.name,
          description: tool.description,
          parameters: parametersSchemaOf(tool),
        ),
    ];
    _state = SharedState(
      host: host,
      codec: codec,
      diagnose: _diagnose,
      onChange: _onStateChange,
    );
  }

  final AgentConnection _connection;
  final StateHost<S> _host;
  final TandemOptions _options;
  final Map<String, Tool<S>> _tools;
  late final List<WireTool> _wireTools;
  late final SharedState<S> _state;

  /// The session's AG-UI thread id. A generated UUID unless
  /// [TandemOptions.threadId] is set.
  final String threadId;

  // Synchronous, because [_changed] already delivers in a microtask of its
  // own.
  final _views = StreamController<TandemView>.broadcast(sync: true);
  final _history = History();
  final _timeline = _Timeline();

  /// User messages that go out with the next run.
  final _queued = <({String id, String text})>[];

  /// Calls of the app's tools that the next run answers, in call order.
  final _calls = <_AppCall<S>>[];

  _Run<S>? _run;
  TandemError? _error;
  TandemView? _view;
  var _isEmitScheduled = false;
  final _idleWaiters = <Completer<void>>[];

  var _isLooping = false;
  var _executingApprovals = 0;

  /// Set by [stop]: nothing starts on its own until the user acts again.
  var _isHalted = false;

  /// Whether the next run is the user's (a message, a decision, a retry)
  /// rather than an automatic follow-up.
  var _isUsersTurn = false;

  /// Automatic follow-up runs in a row, for the loop guard.
  var _autoRuns = 0;

  Future<void>? _disposal;

  /// Set first thing in [dispose], before anything it calls looks at it.
  var _isDisposed = false;

  /// The error of the last failed run if that run had started: the agent
  /// backend may have processed its request already.
  TandemError? _failedAfterStart;

  /// Set by a retry of [_failedAfterStart], for the next run to check that
  /// the backend answered again.
  var _isRetryAfterStart = false;

  bool get _isBusy => _isLooping || _executingApprovals > 0;

  /// The current view, always up to date synchronously.
  TandemView get view => _view ??= TandemView(
    timeline: _timeline.items,
    isRunning: _isBusy,
    marks: _state.marks,
    error: _error,
  );

  /// A new view after every change.
  ///
  /// Broadcast and asynchronous, with no replay: read [view] first. Changes
  /// made in one go come as one view. Closes on [dispose].
  Stream<TandemView> get views => _views.stream;

  /// Sends a user message and runs the agent, including the automatic
  /// follow-up runs.
  ///
  /// Completes when the agent is idle or waits for an approval. Never throws
  /// for a failed run; the failure is in [TandemView.error]. Throws a
  /// [StateError] after [dispose].
  ///
  /// - During a run, the message is queued ([UserMessage.isQueued]) and goes
  ///   out with the next run, after the tools' answers; it also cancels
  ///   further automatic follow-ups.
  /// - Open approval requests are answered first, in the same run: pending
  ///   ones as dismissed, stale ones as invalidated because the state
  ///   changed.
  Future<void> send(String text) {
    if (_isDisposed) {
      throw StateError('The session was disposed, so it cannot send.');
    }
    // An asynchronous host may not have delivered an edit made just before.
    _checkStale();
    _answerOpenApprovals();
    final id = 'user-${newUuid()}';
    _timeline.put(UserMessage(id, text: text, isQueued: _isBusy));
    _queued.add((id: id, text: text));
    _isUsersTurn = true;
    _isHalted = false;
    _changed();
    _kick();
    return _whenIdle();
  }

  /// Cancels the current run and any automatic follow-up.
  ///
  /// - Tool calls the stopped run completed are answered as cancelled with
  ///   the next run; calls it had not finished streaming are dropped.
  /// - A tool that already runs in the app finishes, and its result goes out
  ///   with the next run; the tools waiting after it are answered as
  ///   cancelled.
  /// - Messages the user sent during the run are not dropped: they go out at
  ///   once, in a new run, with those answers. Otherwise nothing runs until
  ///   the user acts again.
  ///
  /// Stopping only stops receiving: the session stops listening and closes
  /// the connection. An AG-UI backend may still finish the run on its own
  /// side, so its agent tools may still run.
  ///
  /// Completes when the session is idle.
  Future<void> stop() async {
    if (_isDisposed) {
      return;
    }
    // Queued messages are the user's turn, not an automatic follow-up.
    _isHalted = _queued.isEmpty;
    for (final call in _calls) {
      if (call.answer == null && call.approval == null && !call.isStarted) {
        call.answer = _payload(const {
          'status': 'cancelled',
        }, toolName: call.tool.name);
        _timeline.put(_activity(call.id, call.tool, ToolActivityStatus.failed));
        _changed();
      }
    }
    final run = _run;
    if (run != null) {
      _endRun(run, _Outcome.stopped);
      await run.cancellation;
    }
    await _whenIdle();
  }

  /// Stops writing to the host synchronously, then stops the run and closes
  /// [views]. Idempotent.
  ///
  /// Dispose the session before the host: with bloc, before the cubit is
  /// closed.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _isDisposed = true;
    final hostClosed = _state.close();
    final run = _run;
    if (run != null) {
      _endRun(run, _Outcome.stopped);
    }
    _notifyIdle();
    await hostClosed;
    await run?.cancellation;
    await _views.close();
  }

  // ------------------------------------------------------------- Run loop

  /// Starts the run loop unless it runs already. The loop starts runs while
  /// there is something to send and nothing to wait for.
  void _kick() {
    if (_isDisposed || _isLooping) {
      return;
    }
    _isLooping = true;
    _changed();
    unawaited(_loop());
  }

  Future<void> _loop() async {
    try {
      while (!_isDisposed) {
        if (_queued.isNotEmpty) {
          // The user wrote after the agent proposed: the proposal is moot.
          _answerOpenApprovals();
        }
        if (_calls.any(
          (call) => call.answer == null && call.approval == null,
        )) {
          await _runTools();
        }
        if (_isDisposed ||
            _isHalted ||
            _calls.any((call) => call.answer == null)) {
          return;
        }
        final isUsersTurn = _isUsersTurn || _queued.isNotEmpty;
        if (!isUsersTurn && _calls.isEmpty) {
          return;
        }
        if (isUsersTurn) {
          _autoRuns = 0;
        } else if (_autoRuns >= _options.maxAutoRuns) {
          _error = TandemError(
            kind: TandemErrorKind.loopGuard,
            message:
                'The agent kept calling tools: ${_options.maxAutoRuns} '
                'automatic follow-up runs in a row. The results wait for the '
                'next message or a retry.',
            onRetry: _retry,
          );
          _changed();
          return;
        } else {
          _autoRuns++;
        }
        _isUsersTurn = false;
        final run = _startRun();
        final outcome = await run.done.future;
        if (_isDisposed) {
          return;
        }
        if (outcome == _Outcome.finished) {
          _finishRun(run);
        } else {
          _abandonRun(run);
          if (outcome == _Outcome.failed || _isHalted) {
            return;
          }
        }
      }
    } finally {
      _isLooping = false;
      _changed();
      _notifyIdle();
    }
  }

  _Run<S> _startRun() {
    _error = null;
    _state.sync();
    final state = _state.startRun();
    for (final call in _calls) {
      _history.addToolMessage(
        '${WireConventions.toolMessagePrefix}${newUuid()}',
        toolCallId: call.id,
        content: call.answer!,
      );
    }
    // A retry that delivers nothing new: the backend may answer it with
    // nothing if it processed the failed run's request already.
    final retries = _isRetryAfterStart && _calls.isEmpty && _queued.isEmpty
        ? _failedAfterStart
        : null;
    _calls.clear();
    for (final (:id, :text) in _queued) {
      _history.addUser(id, text);
      _timeline.put(UserMessage(id, text: text));
    }
    _queued.clear();
    final edits = _state.takeUserEdits();
    final reported = _options.reportUserEdits ? edits : const <String>[];
    final input = RunInput(
      threadId: threadId,
      runId: newUuid(),
      messages: _history.messages,
      tools: _wireTools,
      state: state,
      context: [
        for (final MapEntry(:key, :value) in _options.context.entries)
          WireContext(description: key, value: value),
        if (reported.isNotEmpty)
          WireContext(
            description: WireConventions.userEditsDescription,
            value: jsonEncode(reported),
          ),
      ],
    );
    final run = _Run<S>(input, reportedEdits: reported, retries: retries);
    _isRetryAfterStart = false;
    _failedAfterStart = null;
    _run = run;
    _changed();
    try {
      run.subscription = _connection
          .run(input)
          .listen(
            (event) => _onEvent(run, event),
            onError: (Object error) =>
                _endRun(run, _Outcome.failed, error: _connectionError(error)),
            onDone: () => _endRun(run, _Outcome.finished),
            cancelOnError: true,
          );
    } on Object catch (error) {
      _endRun(run, _Outcome.failed, error: _connectionError(error));
    }
    return run;
  }

  void _endRun(_Run<S> run, _Outcome outcome, {TandemError? error}) {
    if (run.outcome != null) {
      return;
    }
    run
      ..outcome = outcome
      ..error = error;
    if (identical(_run, run)) {
      _run = null;
    }
    final subscription = run.subscription;
    if (subscription != null) {
      run.cancellation = subscription.cancel();
    }
    run.done.complete(outcome);
  }

  /// After a run that finished: completes what it left open and turns the
  /// calls of the app's tools into work for the loop.
  void _finishRun(_Run<S> run) {
    _closeTextChunk(run);
    _closeToolChunk(run);
    for (final id in run.texts.keys.toList()) {
      _endText(run, id);
    }
    // After all of the run's state events: what an approval refers to. The
    // agent proposed without seeing the user's edits made during the run,
    // so with any such edit left, its requests start stale.
    _state.sync();
    final reference = _state.encode();
    final initialApproval = _state.hasUserEdits
        ? ApprovalStatus.stale
        : ApprovalStatus.pending;
    for (final MapEntry(key: id, value: call) in run.calls.entries) {
      final tool = call.tool;
      if (tool == null) {
        // An agent tool shows running until its TOOL_CALL_RESULT, which a
        // long-running one sends in a later run.
        if (!call.isComplete && !call.hasResult) {
          _setActivity(id, ToolActivityStatus.failed);
        }
        continue;
      }
      if (call.hasResult) {
        _setActivity(id, ToolActivityStatus.succeeded);
        continue;
      }
      if (!call.isComplete) {
        _timeline.put(_activity(id, tool, ToolActivityStatus.failed));
        continue;
      }
      final args = _decodeArguments(call.arguments);
      final problem = args == null
          ? ToolArgumentError(
              'arguments',
              'must be a JSON object, not ${call.arguments}',
            )
          : checkArguments(tool, args);
      final appCall = _AppCall(id, tool, args ?? const {});
      _calls.add(appCall);
      if (problem != null) {
        appCall.answer = _errorPayload(problem);
        _timeline.put(_activity(id, tool, ToolActivityStatus.failed));
      } else if (tool.needsApproval) {
        appCall
          ..approval = initialApproval
          ..reference = reference;
        _timeline.put(_approvalRequest(appCall));
      }
    }
    if (run.retries case final failure? when !run.hasContent) {
      _error = _failedAfterStart = TandemError(
        kind: failure.kind,
        message:
            'The agent backend had already received the request of the '
            'failed run and did not answer it again, so its answer is lost. '
            'Send a new message to go on.',
        onRetry: _retry,
      );
    }
    _changed();
  }

  /// After a run that was stopped or failed: completed calls of the app's
  /// tools are answered as cancelled, everything unfinished shows as failed.
  void _abandonRun(_Run<S> run) {
    _history.dropUnfinished();
    for (final id in run.texts.keys) {
      if (_timeline.message(id) case AgentMessage(:final text)) {
        _timeline.put(AgentMessage(id, text: text));
      }
    }
    for (final MapEntry(key: id, value: call) in run.calls.entries) {
      final tool = call.tool;
      if (call.hasResult) {
        _setActivity(id, ToolActivityStatus.succeeded);
        continue;
      }
      if (tool == null) {
        _setActivity(id, ToolActivityStatus.failed);
        continue;
      }
      if (!call.isComplete) {
        _timeline.put(_activity(id, tool, ToolActivityStatus.failed));
        continue;
      }
      final appCall = _AppCall(
        id,
        tool,
        _decodeArguments(call.arguments) ?? const {},
      )..answer = _payload(const {'status': 'cancelled'}, toolName: tool.name);
      _calls.add(appCall);
      if (tool.needsApproval) {
        // The user still sees what the agent proposed.
        appCall.approval = ApprovalStatus.dismissed;
        _timeline.put(_approvalRequest(appCall));
      } else {
        _timeline.put(_activity(id, tool, ToolActivityStatus.failed));
      }
    }
    if (!run.isStarted) {
      _state.restoreUserEdits(run.reportedEdits);
    }
    if (run.error case final error?) {
      _error = error;
      _failedAfterStart = run.isStarted ? error : null;
    }
    _changed();
  }

  /// Runs the calls of tools without approval, one after another in call
  /// order.
  Future<void> _runTools() async {
    for (final call in List.of(_calls)) {
      if (call.answer != null || call.approval != null) {
        continue;
      }
      if (_isDisposed) {
        return;
      }
      final tool = call.tool;
      call.isStarted = true;
      try {
        final result = await tool.run(_toolCall(call));
        call.answer = _payload({
          'status': 'ok',
          'result': result,
        }, toolName: tool.name);
        _timeline.put(_activity(call.id, tool, ToolActivityStatus.succeeded));
      } on Object catch (error) {
        call.answer = _errorPayload(error);
        _timeline.put(_activity(call.id, tool, ToolActivityStatus.failed));
      }
      _changed();
    }
  }

  // ------------------------------------------------------------ Approvals

  Future<void> _approve(_AppCall<S> call) async {
    if (_isDisposed || call.approval != ApprovalStatus.pending) {
      return;
    }
    _checkStale();
    if (call.approval != ApprovalStatus.pending) {
      return;
    }
    final tool = call.tool;
    // The live state equals the reference state now.
    final toolCall = _toolCall(call);
    call.approval = ApprovalStatus.executing;
    _executingApprovals++;
    _isUsersTurn = true;
    _isHalted = false;
    _timeline.put(_approvalRequest(call));
    _changed();
    try {
      final result = await tool.run(toolCall);
      call
        ..approval = ApprovalStatus.executed
        ..result = result
        ..answer = _payload({
          'status': 'executed',
          'approved': true,
          'result': result,
        }, toolName: tool.name);
    } on Object catch (error) {
      call
        ..approval = ApprovalStatus.failed
        ..failure = '$error'
        ..answer = _payload({
          'status': 'failed',
          'approved': true,
          'error': '$error',
        }, toolName: tool.name);
    } finally {
      _executingApprovals--;
    }
    if (_isDisposed) {
      return;
    }
    _timeline.put(_approvalRequest(call));
    _changed();
    _kick();
    _notifyIdle();
  }

  Future<void> _reject(_AppCall<S> call) async {
    if (_isDisposed ||
        (call.approval != ApprovalStatus.pending &&
            call.approval != ApprovalStatus.stale)) {
      return;
    }
    call
      ..approval = ApprovalStatus.rejected
      ..answer = _payload(const {
        'status': 'rejected',
        'approved': false,
      }, toolName: call.tool.name);
    _isUsersTurn = true;
    _isHalted = false;
    _timeline.put(_approvalRequest(call));
    _changed();
    _kick();
  }

  /// The user wrote while approval requests were open: pending ones are
  /// dismissed, stale ones invalidated.
  void _answerOpenApprovals() {
    for (final call in _calls) {
      final Map<String, Object?> payload;
      switch (call.approval) {
        case ApprovalStatus.pending:
          payload = const {
            'status': 'dismissed',
            'approved': false,
            'reason': 'user_sent_message',
          };
        case ApprovalStatus.stale:
          payload = const {
            'status': 'invalidated',
            'approved': false,
            'reason': 'state_changed',
          };
        default:
          continue;
      }
      call
        ..approval = ApprovalStatus.dismissed
        ..answer = _payload(payload, toolName: call.tool.name);
      _timeline.put(_approvalRequest(call));
      _changed();
    }
  }

  /// Makes every pending request whose reference state differs from the
  /// live state stale.
  void _checkStale() {
    final pending = [
      for (final call in _calls)
        if (call.approval == ApprovalStatus.pending) call,
    ];
    if (pending.isEmpty) {
      return;
    }
    final current = _state.encode();
    for (final call in pending) {
      if (!jsonEquals(current, call.reference)) {
        call.approval = ApprovalStatus.stale;
        _timeline.put(_approvalRequest(call));
        _changed();
      }
    }
  }

  Future<void> _retry() {
    if (_isDisposed) {
      return Future.value();
    }
    if (!_isBusy) {
      _isUsersTurn = true;
      _isHalted = false;
      _isRetryAfterStart = _failedAfterStart != null;
      _kick();
    }
    return _whenIdle();
  }

  // --------------------------------------------------------------- Events

  void _onEvent(_Run<S> run, WireEvent event) {
    if (run.outcome != null || _isDisposed) {
      return;
    }
    if (event is! RunStarted && event is! RunFinished) {
      run.hasContent = true;
    }
    if (event is! TextChunk) {
      _closeTextChunk(run);
    }
    if (event is! ToolCallChunk) {
      _closeToolChunk(run);
    }
    switch (event) {
      case RunStarted():
        run.isStarted = true;
      case RunFinished():
        _endRun(run, _Outcome.finished);
      case RunError(:final message, :final code):
        _endRun(
          run,
          _Outcome.failed,
          error: TandemError(
            kind: TandemErrorKind.agent,
            message: message.isEmpty ? 'The agent failed the run.' : message,
            code: code,
            onRetry: _retry,
          ),
        );
      case TextStart(:final messageId):
        _startText(run, messageId);
      case TextContent(:final messageId, :final delta):
        _appendText(run, messageId, delta);
      case TextEnd(:final messageId):
        _endText(run, messageId);
      case TextChunk():
        _onTextChunk(run, event);
      case ToolCallStart(:final toolCallId, :final toolCallName):
        _startCall(run, toolCallId, toolCallName, event.parentMessageId);
      case ToolCallArgs(:final toolCallId, :final delta):
        _appendArguments(run, toolCallId, delta);
      case ToolCallEnd(:final toolCallId):
        _endCall(run, toolCallId);
      case ToolCallChunk():
        _onToolChunk(run, event);
      case ToolCallResult():
        _onResult(run, event);
      case StateSnapshot(:final snapshot):
        _state.applySnapshot(snapshot);
      case StateDelta(:final operations):
        _state.applyDelta(operations);
      case MessagesSnapshot(:final messages):
        _history.replace(messages);
      case UnknownEvent(:final problem):
        _diagnose(
          problem == null
              ? 'Ignored an event of the unknown type "${event.type}".'
              : 'Ignored an event that could not be read: $problem',
          event.json,
        );
    }
    _changed();
  }

  void _startText(_Run<S> run, String id) {
    if (run.texts.containsKey(id)) {
      return;
    }
    run.texts[id] = StringBuffer();
    _history.startText(id);
    _timeline.put(AgentMessage(id, text: '', isStreaming: true));
  }

  void _appendText(_Run<S> run, String id, String delta) {
    final text = run.texts[id];
    if (text == null) {
      _diagnose('Ignored text of the message "$id", which is not open.');
      return;
    }
    text.write(delta);
    _timeline.put(AgentMessage(id, text: '$text', isStreaming: true));
  }

  void _endText(_Run<S> run, String id) {
    final text = run.texts.remove(id);
    if (text == null) {
      _diagnose('Ignored the end of text message "$id", which never started.');
      return;
    }
    _history.addText(id, '$text');
    _timeline.put(AgentMessage(id, text: '$text'));
  }

  void _onTextChunk(_Run<S> run, TextChunk chunk) {
    final id = chunk.messageId ?? run.textChunk;
    if (id == null) {
      _diagnose(
        'Ignored a TEXT_MESSAGE_CHUNK without messageId that continues no '
        'message.',
        chunk.json,
      );
      return;
    }
    if (id != run.textChunk) {
      _closeTextChunk(run);
      _startText(run, id);
      run.textChunk = id;
    }
    if (chunk.delta case final delta?) {
      _appendText(run, id, delta);
    }
  }

  void _closeTextChunk(_Run<S> run) {
    final id = run.textChunk;
    if (id != null) {
      run.textChunk = null;
      _endText(run, id);
    }
  }

  void _startCall(
    _Run<S> run,
    String id,
    String name,
    String? parentMessageId,
  ) {
    if (run.calls.containsKey(id) || _history.containsCall(id)) {
      _diagnose('Ignored a second start of the tool call "$id".');
      return;
    }
    final tool = _tools[name];
    run.calls[id] = _ReceivedCall(name, tool, parentMessageId);
    if (tool == null) {
      _timeline.put(
        ToolActivity(
          id,
          toolName: name,
          label: _options.toolLabels[name] ?? nameInWords(name),
          status: ToolActivityStatus.running,
          runsInApp: false,
        ),
      );
    } else if (tool.needsApproval) {
      // Shown as an approval request when the run ends.
      _timeline.reserve(id);
    } else {
      _timeline.put(_activity(id, tool, ToolActivityStatus.running));
    }
  }

  void _appendArguments(_Run<S> run, String id, String delta) {
    final call = run.calls[id];
    if (call == null || call.isComplete) {
      _diagnose('Ignored arguments of the tool call "$id", which is not open.');
      return;
    }
    call.appendArguments(delta);
  }

  void _endCall(_Run<S> run, String id) {
    final call = run.calls[id];
    if (call == null || call.isComplete) {
      _diagnose('Ignored the end of the tool call "$id", which is not open.');
      return;
    }
    call.isComplete = true;
    _history.addToolCall(
      call.parentMessageId ?? '${WireConventions.assistantMessagePrefix}$id',
      WireToolCall(id: id, name: call.name, arguments: call.arguments),
    );
    if (call.result case (:final messageId, :final content)) {
      _history.addToolMessage(messageId, toolCallId: id, content: content);
    }
  }

  void _onToolChunk(_Run<S> run, ToolCallChunk chunk) {
    final id = chunk.toolCallId ?? run.toolChunk;
    if (id == null) {
      _diagnose(
        'Ignored a TOOL_CALL_CHUNK without toolCallId that continues no '
        'call.',
        chunk.json,
      );
      return;
    }
    if (id != run.toolChunk) {
      _closeToolChunk(run);
      if (!run.calls.containsKey(id)) {
        final name = chunk.toolCallName;
        if (name == null) {
          _diagnose(
            'Ignored the TOOL_CALL_CHUNK that starts the call "$id" without '
            'toolCallName.',
            chunk.json,
          );
          return;
        }
        _startCall(run, id, name, chunk.parentMessageId);
      }
      run.toolChunk = id;
    }
    if (chunk.delta case final delta?) {
      _appendArguments(run, id, delta);
    }
  }

  void _closeToolChunk(_Run<S> run) {
    final id = run.toolChunk;
    if (id != null) {
      run.toolChunk = null;
      _endCall(run, id);
    }
  }

  void _onResult(_Run<S> run, ToolCallResult result) {
    final ToolCallResult(:messageId, :toolCallId, :content) = result;
    final call = run.calls[toolCallId];
    if (call != null) {
      call.hasResult = true;
      if (call.isComplete) {
        _history.addToolMessage(
          messageId,
          toolCallId: toolCallId,
          content: content,
        );
      } else {
        // Its assistant message comes first, at the end of the call.
        call.result = (messageId: messageId, content: content);
      }
    } else if (_history.containsCall(toolCallId)) {
      _history.addToolMessage(
        messageId,
        toolCallId: toolCallId,
        content: content,
      );
    } else {
      _diagnose(
        'Ignored the result of the tool call "$toolCallId", which the agent '
        'never made.',
        result.json,
      );
      return;
    }
    _setActivity(toolCallId, ToolActivityStatus.succeeded);
  }

  // -------------------------------------------------------------- Helpers

  void _onStateChange() {
    _checkStale();
    _changed();
  }

  ToolCall<S> _toolCall(_AppCall<S> call) => ToolCall(
    id: call.id,
    toolName: call.tool.name,
    state: _host.state,
    args: call.args,
  );

  ToolActivity _activity(String id, Tool<S> tool, ToolActivityStatus status) =>
      ToolActivity(
        id,
        toolName: tool.name,
        label: tool.label ?? nameInWords(tool.name),
        status: status,
        runsInApp: true,
      );

  ApprovalRequest _approvalRequest(_AppCall<S> call) => ApprovalRequest(
    call.id,
    toolName: call.tool.name,
    label: call.tool.label ?? nameInWords(call.tool.name),
    args: ToolArgs(call.args),
    status: call.approval!,
    onApprove: () => _approve(call),
    onReject: () => _reject(call),
    result: call.result,
    failure: call.failure,
  );

  /// Sets the status of a visible tool activity that is still running.
  void _setActivity(String id, ToolActivityStatus status) {
    if (_timeline.activity(id) case final activity?
        when activity.status == ToolActivityStatus.running) {
      _timeline.put(
        ToolActivity(
          id,
          toolName: activity.toolName,
          label: activity.label,
          status: status,
          runsInApp: activity.runsInApp,
        ),
      );
    }
  }

  String _errorPayload(Object error) =>
      jsonEncode({'status': 'error', 'error': '$error'});

  /// [payload] as a tool message's content. A result that `jsonEncode`
  /// cannot encode is sent as its `toString()` and reported.
  String _payload(Map<String, Object?> payload, {required String toolName}) {
    try {
      return jsonEncode(payload);
    } on Object catch (error) {
      // Usually a JsonUnsupportedObjectError: an object without toJson(), or
      // a toJson() that threw.
      _diagnose(
        'The result of the tool "$toolName" could not be encoded as JSON; '
        'the agent gets its toString() instead.',
        error,
      );
      return jsonEncode({...payload, 'result': '${payload['result']}'});
    }
  }

  static Map<String, Object?>? _decodeArguments(String arguments) {
    if (arguments.trim().isEmpty) {
      return const {};
    }
    try {
      return switch (jsonDecode(arguments)) {
        final Map<String, Object?> json => json,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  TandemError _connectionError(Object error) => TandemError(
    kind: TandemErrorKind.connection,
    message: '$error',
    onRetry: _retry,
  );

  void _diagnose(String message, [Object? detail]) {
    final diagnostic = TandemDiagnostic(message, detail: detail);
    final onDiagnostic = _options.onDiagnostic;
    if (onDiagnostic != null) {
      onDiagnostic(diagnostic);
    } else {
      developer.log(message, name: 'tandem', error: detail);
    }
  }

  /// The view changed: [view] is rebuilt on the next read, and [views] gets
  /// it in a microtask.
  void _changed() {
    _view = null;
    if (_isEmitScheduled || _views.isClosed) {
      return;
    }
    _isEmitScheduled = true;
    scheduleMicrotask(() {
      _isEmitScheduled = false;
      if (!_views.isClosed) {
        _views.add(view);
      }
    });
  }

  Future<void> _whenIdle() {
    if (!_isBusy || _isDisposed) {
      return Future.value();
    }
    final waiter = Completer<void>();
    _idleWaiters.add(waiter);
    return waiter.future;
  }

  void _notifyIdle() {
    if (_isBusy && !_isDisposed) {
      return;
    }
    final waiters = List.of(_idleWaiters);
    _idleWaiters.clear();
    for (final waiter in waiters) {
      waiter.complete();
    }
  }

  static Map<String, Tool<T>> _toolsByName<T>(List<Tool<T>> tools) {
    final byName = <String, Tool<T>>{};
    for (final tool in tools) {
      if (!isValidToolName(tool.name)) {
        throw ArgumentError.value(
          tool.name,
          'tools',
          'A tool name must match [a-zA-Z0-9_-]{1,64}',
        );
      }
      if (byName.containsKey(tool.name)) {
        throw ArgumentError.value(
          tool.name,
          'tools',
          'Two tools have the same name',
        );
      }
      byName[tool.name] = tool;
    }
    return byName;
  }
}

/// How a run ended.
enum _Outcome {
  /// `RUN_FINISHED`, or the stream ended without it.
  finished,

  /// [TandemSession.stop] or [TandemSession.dispose].
  stopped,

  /// `RUN_ERROR` or a transport error.
  failed,
}

/// One run in progress.
final class _Run<S> {
  _Run(this.input, {required this.reportedEdits, this.retries});

  final RunInput input;

  /// The user edits this run reports, given back when it never starts.
  final List<String> reportedEdits;

  /// The failure of a run that had started, when this run retries it
  /// without delivering anything new.
  final TandemError? retries;

  StreamSubscription<WireEvent>? subscription;
  Future<void>? cancellation;
  final done = Completer<_Outcome>();
  _Outcome? outcome;
  TandemError? error;

  /// Whether `RUN_STARTED` arrived.
  bool isStarted = false;

  /// Whether anything other than `RUN_STARTED` and `RUN_FINISHED` arrived.
  bool hasContent = false;

  /// Text messages in progress, by message id.
  final texts = <String, StringBuffer>{};

  /// The message of the `TEXT_MESSAGE_CHUNK`s in progress.
  String? textChunk;

  /// The call of the `TOOL_CALL_CHUNK`s in progress.
  String? toolChunk;

  /// Every tool call of the run, by id, in call order.
  final calls = <String, _ReceivedCall<S>>{};
}

/// A tool call as the run streams it.
final class _ReceivedCall<S> {
  _ReceivedCall(this.name, this.tool, this.parentMessageId);

  final String name;

  /// The app's tool, `null` for an agent tool.
  final Tool<S>? tool;
  final String? parentMessageId;
  final _arguments = StringBuffer();
  bool isComplete = false;

  /// Whether the agent sent a `TOOL_CALL_RESULT` for the call.
  bool hasResult = false;

  /// A `TOOL_CALL_RESULT` that arrived while the call was open.
  ({String messageId, String content})? result;

  void appendArguments(String delta) => _arguments.write(delta);

  /// The JSON-encoded arguments, `'{}'` when the agent sent none.
  String get arguments => _arguments.isEmpty ? '{}' : '$_arguments';
}

/// A call of one of the app's tools that a later run answers.
final class _AppCall<S> {
  _AppCall(this.id, this.tool, this.args);

  final String id;
  final Tool<S> tool;
  final Map<String, Object?> args;

  /// The tool message content, once known.
  String? answer;

  /// Whether the tool of a call without approval was started.
  bool isStarted = false;

  /// For a tool with [Tool.needsApproval]: where the request is.
  ApprovalStatus? approval;

  /// The encoded shared state when the request was made.
  Map<String, Object?>? reference;

  Object? result;
  String? failure;
}

/// The timeline: items in order, by id, with places kept for items that
/// show up later.
final class _Timeline {
  final _items = <TimelineItem?>[];
  final _indexes = <String, int>{};
  List<TimelineItem>? _visible;

  /// The visible items, in order.
  List<TimelineItem> get items =>
      _visible ??= List.unmodifiable(_items.nonNulls);

  /// Adds [item], or replaces the item with its id in place.
  void put(TimelineItem item) {
    final key = _key(
      item.id,
      isCall: item is ToolActivity || item is ApprovalRequest,
    );
    final index = _indexes[key];
    if (index == null) {
      _indexes[key] = _items.length;
      _items.add(item);
    } else {
      _items[index] = item;
    }
    _visible = null;
  }

  /// Keeps the place for the item of the tool call [id], hidden until it is
  /// [put].
  void reserve(String id) {
    _indexes.putIfAbsent(_key(id, isCall: true), () {
      _items.add(null);
      return _items.length - 1;
    });
  }

  /// The item of the agent message [id], if it is visible.
  TimelineItem? message(String id) => _at(_key(id, isCall: false));

  /// The tool activity of the call [id], if it is visible.
  ToolActivity? activity(String id) => switch (_at(_key(id, isCall: true))) {
    final ToolActivity activity => activity,
    _ => null,
  };

  TimelineItem? _at(String key) => switch (_indexes[key]) {
    final index? => _items[index],
    null => null,
  };

  /// Messages and calls have ids of their own, which may coincide.
  static String _key(String id, {required bool isCall}) =>
      isCall ? 'call:$id' : 'message:$id';
}
