# Tandem: interface of the spike

Status: **approved** (2026-10-16). Chosen in a Design It Twice round: the base is the
"attach, don't adopt" design, with the strict scripted agent from the ports-and-adapters design and
the fixes its critic found. Vocabulary: [GLOSSARY.md](../GLOSSARY.md). Decisions:
[ADR 0001](adr/0001-own-protocol-model-behind-agent-connection.md),
[ADR 0002](adr/0002-attach-to-the-apps-state-host.md).

## What a caller writes

The screen's existing cubit gains one clause, the route gains one widget.

```dart
class OrderCubit extends Cubit<OrderState> with AgentEditable<OrderState> {
  // existing methods unchanged
}

BlocProvider(
  create: (_) => OrderCubit(),
  child: TandemScope<OrderCubit, OrderState>(
    codec: StateCodec.lens(
      'order',
      get: (state) => state.draft,
      set: (state, draft) => state.copyWith(draft: draft),
      fromJson: OrderDraft.fromJson,
      toJson: (draft) => draft.toJson(),
    ),
    tools: (context) => [
      Tool('search_catalog', 'Find products matching free text from the e-mail.',
          params: {'query': const Param.string('For example "HDMI cable 2m"')},
          run: (call) => context.read<Catalog>().search(call.read('query'))),
      Tool('place_order', 'Place the order exactly as it is on the screen.',
          needsApproval: true,
          run: (call) => context.read<Orders>().place(call.state.draft)),
    ],
    child: const OrderScreen(),
  ),
)
```

In the UI: `context.watch<TandemCubit>().state` is a `TandemView` (timeline, marks, error),
`request.approve()` / `request.reject()` on an approval request, `view.marks.has('lines/1/quantity')`
for highlighting.

## Packages

- `tandem` (root): the core. Its code imports no Flutter and no bloc, so it is tested with plain tests.
  Dependencies: `http`, `meta`. Libraries: `tandem.dart` (callers), `protocol.dart` (adapter authors),
  `testing.dart` (callers' tests).
- `packages/tandem_bloc`: `AgentEditable`, `TandemCubit`, `TandemScope`. Depends on `flutter`, `flutter_bloc`, `tandem`.
- `example/`: the B2B order demo app; `example/agent/`: its Google ADK agent.

## `package:tandem/tandem.dart`

```dart
// ---------------------------------------------------------------- Session

/// One session with the agent for one screen.
final class TandemSession<S> {
  /// Starts listening to [host]; sends nothing until the first [send].
  /// Throws ArgumentError when two tools share a name or a name does not
  /// match [a-zA-Z0-9_-]{1,64}.
  TandemSession({
    required AgentConnection connection,
    required StateHost<S> host,
    required StateCodec<S> codec,
    List<Tool<S>> tools = const [],
    TandemOptions options = const TandemOptions(),
  });

  /// The AG-UI thread id. Generated unless [TandemOptions.threadId] is set.
  String get threadId;

  /// The current view, always up to date synchronously.
  TandemView get view;

  /// A new view after every change. Broadcast, asynchronous, no replay
  /// (read [view] first). Closes on [dispose].
  Stream<TandemView> get views;

  /// Sends a user message and runs the agent, including automatic follow-up
  /// runs. Completes when the agent is idle or waits for an approval.
  /// Never throws for run failures (see [TandemView.error]); StateError after
  /// dispose. During a run the message is queued and goes out with the next
  /// run. Open approval requests are answered first, in the same run.
  Future<void> send(String text);

  /// Cancels the current run and any automatic follow-up. Messages queued
  /// during the run then go out at once. Only stops receiving: the backend
  /// may still finish the run on its side.
  Future<void> stop();

  /// Stops writing to the host synchronously, then stops the run and closes
  /// [views]. Idempotent.
  Future<void> dispose();
}

final class TandemOptions {
  const TandemOptions({
    this.toolLabels = const {},   // timeline labels for agent tools
    this.maxAutoRuns = 5,         // loop guard for follow-up runs in a row
    this.reportUserEdits = true,  // tell the agent which fields the user changed
    this.context = const {},      // extra context sent with every run
    this.threadId,                // default: a generated UUID
    this.onDiagnostic,            // default: dart:developer log('tandem')
  });
  final Map<String, String> toolLabels;
  final int maxAutoRuns;
  final bool reportUserEdits;
  final Map<String, String> context;
  final String? threadId;
  final void Function(TandemDiagnostic diagnostic)? onDiagnostic;
}

/// Something the session ignored so the run could go on: an unknown event, a
/// patch that failed, a decode error, a result that could not be encoded.
final class TandemDiagnostic {
  const TandemDiagnostic(this.message, {this.detail});
  final String message;
  final Object? detail;
}

// ----------------------------------------------------------- Shared state

/// Where the shared state lives in the app. Tandem reads it, listens to it
/// and writes the agent's changes into it; it never owns it. The member names
/// match bloc's StateStreamable, so a Cubit already has [state] and [stream].
abstract interface class StateHost<S> {
  factory StateHost.memory(S initial) = MemoryStateHost<S>;
  S get state;
  /// Every new value from any writer, including echoes of [writeFromAgent].
  /// May be asynchronous.
  Stream<S> get stream;
  /// Called by Tandem only. Afterwards [state] is [value].
  void writeFromAgent(S value);
}

/// A host for plain Dart callers and tests.
final class MemoryStateHost<S> implements StateHost<S> {
  MemoryStateHost(S initial);
  /// A user edit.
  void update(S Function(S current) edit);
}

/// Converts between the app's state and the JSON document the agent sees.
/// The app owns [keys] (top-level); the agent backend owns the rest, which is
/// never sent back. [encode] must be deterministic.
abstract base class StateCodec<S> {
  const StateCodec();

  /// The whole state is one model under [key].
  factory StateCodec.json(
    String key,
    S Function(Map<String, Object?> json) fromJson, {
    required Map<String, Object?> Function(S value) toJson,
  });

  /// Only part of the state is shared, e.g. the draft inside a cubit state
  /// that also holds UI flags. [set] puts an agent-built model back and keeps
  /// the rest.
  static StateCodec<S> lens<S, M>(
    String key, {
    required M Function(S state) get,
    required S Function(S state, M model) set,
    required M Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(M model) toJson,
  });

  /// Full control over several owned keys.
  factory StateCodec.custom({
    required Set<String> keys,
    required Map<String, Object?> Function(S state) encode,
    required S Function(S current, Map<String, Object?> document) decode,
  });

  Set<String> get keys;
  /// Returns exactly [keys].
  Map<String, Object?> encode(S state);
  /// May throw: the session then keeps the current value and reports a diagnostic.
  S decode(S current, Map<String, Object?> document);
}

// ------------------------------------------------------------------ Tools

/// A function of the app the agent may call. With [needsApproval] it runs
/// only after the user approves that exact call while the shared state is
/// unchanged. Agent tools are never declared here.
final class Tool<S> {
  Tool(
    this.name,
    this.description, {
    required FutureOr<Object?> Function(ToolCall<S> call) run,
    this.params = const {},
    this.needsApproval = false,
    this.label,                    // timeline text; default: the name in words
  });
  final String name;
  final String description;
  final Map<String, Param> params;
  final bool needsApproval;
  final String? label;
  /// Public so a tool can be unit-tested. Return value is sent as
  /// {"status":"ok","result":...}; a throw as {"status":"error","error":"..."}.
  FutureOr<Object?> run(ToolCall<S> call);
}

/// One argument of a tool; becomes JSON Schema (without additionalProperties,
/// which Gemini rejects). Required unless [optional]. Arguments are validated
/// before run is called.
final class Param {
  const Param.string(this.description, {this.optional = false, List<String>? oneOf});
  const Param.integer(this.description, {this.optional = false});
  const Param.number(this.description, {this.optional = false});
  const Param.boolean(this.description, {this.optional = false});
  const Param.list(Param items, this.description, {this.optional = false});
  const Param.object(Map<String, Param> fields, this.description, {this.optional = false});
  final String description;
  final bool optional;
  Map<String, Object?> toJsonSchema();
}

/// Typed reads of JSON arguments; T is inferred from where the value goes.
base class ToolArgs {
  ToolArgs(this.json);
  final Map<String, Object?> json; // {} when the agent sent no arguments
  /// String, int (accepts 40.0), double (accepts 15), num, bool,
  /// List<Object?>, Map<String, Object?>. Throws ToolArgumentError, which is
  /// sent back to the agent.
  T read<T>(String name);
  T? readOrNull<T>(String name);
  List<T> readList<T>(String name);
  ToolArgs object(String name);
  List<ToolArgs> objects(String name);
}

/// One call, passed to [Tool.run].
final class ToolCall<S> extends ToolArgs {
  final String id;
  final String toolName;
  /// The shared state when run starts; for an approval, the approved state.
  final S state;
}

final class ToolArgumentError extends Error {
  ToolArgumentError(this.argument, this.message);
  final String argument;
  final String message;
}

// ------------------------------------------------------------------- View

/// Everything the UI shows, as one immutable value. Not generic, so
/// context.watch<TandemCubit>() needs no type arguments.
final class TandemView {
  static const TandemView initial;
  final List<TimelineItem> timeline;
  final bool isRunning;
  final AgentMarks marks;
  final TandemError? error;                // cleared when the next run starts
  List<ApprovalRequest> get openApprovals; // pending or stale
}

sealed class TimelineItem {
  final String id; // stable, usable as a widget key
}

final class UserMessage extends TimelineItem {
  final String text;
  final bool isQueued; // sent during a run, goes out with the next one
}

final class AgentMessage extends TimelineItem {
  final String text;
  final bool isStreaming;
}

final class ToolActivity extends TimelineItem {
  final String toolName;
  final String label;
  final ToolActivityStatus status;
  final bool runsInApp; // tool (true) or agent tool (false)
}

enum ToolActivityStatus { running, succeeded, failed }

/// The user's decision point for one call of a tool with needsApproval.
final class ApprovalRequest extends TimelineItem {
  final String toolName;
  final String label;
  final ToolArgs args;             // exactly as proposed
  final ApprovalStatus status;
  final Object? result;            // what run returned, once executed
  final String? failure;           // once failed
  /// Only while pending. While true, the live shared state equals the state
  /// at proposal, so a card can render the live state.
  bool get canApprove;
  bool get isStale;                // "The details changed, ask the assistant again"
  bool get canReject;              // pending or stale
  /// Re-checks the state, runs the tool, reports the outcome in a follow-up
  /// run. No-op unless canApprove. Completes when the tool has run.
  Future<void> approve();
  /// No-op unless canReject.
  Future<void> reject();
}

enum ApprovalStatus { pending, stale, executing, executed, failed, rejected, dismissed }

/// Which leaves of the shared state the agent wrote last. Paths use '/',
/// are relative to the codec key (json, lens) and use list indexes.
final class AgentMarks {
  static const AgentMarks none;
  /// The agent is the last writer of this leaf or of a leaf below it. A user
  /// edit of the leaf clears it.
  bool has(String path);
  /// Changed in the agent's most recent update.
  bool isLatest(String path);
  Set<String> get paths;
}

final class TandemError {
  final TandemErrorKind kind;
  final String message;
  final String? code;         // RUN_ERROR code
  /// Sends everything not yet delivered, without a new user message.
  Future<void> retry();
}

enum TandemErrorKind { connection, agent, loopGuard }

// --------------------------------------------------------- Connection seam

/// Runs one run against an agent backend. Adapters: [AgentConnection.http],
/// ScriptedAgent (testing.dart). Another AG-UI Dart package would be one
/// more adapter.
abstract interface class AgentConnection {
  factory AgentConnection.http(
    Uri endpoint, {
    FutureOr<Map<String, String>> Function()? headers, // called once per run
    Duration idleTimeout,                             // default 60 s (ADK pings every 15 s)
    http.Client Function()? newClient,                // a fresh client per run
  }) = HttpSseConnection;

  /// Lazy and single-listen; cancelling the subscription aborts the run. Ends
  /// after RUN_FINISHED or RUN_ERROR, or early. Transport failures are stream
  /// errors; unknown events are UnknownEvent values, never errors.
  Stream<WireEvent> run(RunInput input);
}
```

The view types (`TandemView`, the `TimelineItem` subclasses, `AgentMarks`, `TandemError`) and
`RunRequest` also have public constructors, on purpose: widget and golden tests of an app's own timeline
and approval cards build views without a session. The session's callbacks (`onApprove`, `onReject`,
`onRetry`) are their parameters, so changing those signatures is a breaking change.

## `package:tandem/protocol.dart` (adapter authors only)

```dart
final class RunInput {
  const RunInput({
    required String threadId,
    required String runId,
    required List<WireMessage> messages,
    required List<WireTool> tools,
    required Map<String, Object?> state,
    List<WireContext> context = const [],
    Map<String, Object?> forwardedProps = const {},
  });
  Map<String, Object?> toJson(); // the AG-UI request body, camelCase
}

sealed class WireMessage { String get id; Map<String, Object?> toJson(); static WireMessage? fromJson(Map<String, Object?> json); }
final class WireUserMessage extends WireMessage { const WireUserMessage(String id, String content); }
final class WireAssistantMessage extends WireMessage { const WireAssistantMessage(String id, {String? content, List<WireToolCall> toolCalls = const []}); }
final class WireToolMessage extends WireMessage { const WireToolMessage(String id, {required String toolCallId, required String content}); }
final class WireToolCall { const WireToolCall({required String id, required String name, required String arguments}); }
final class WireTool { const WireTool({required String name, required String description, required Map<String, Object?> parameters}); }
final class WireContext { const WireContext({required String description, required String value}); }

/// Keeps the raw JSON of every event; decoding never throws.
sealed class WireEvent {
  factory WireEvent.fromJson(Map<String, Object?> json);
  Map<String, Object?> get json;
  String get type;
}
// RunStarted, RunFinished, RunError, TextStart, TextContent, TextEnd, TextChunk,
// ToolCallStart, ToolCallArgs, ToolCallEnd, ToolCallChunk, ToolCallResult,
// StateSnapshot, StateDelta, MessagesSnapshot, UnknownEvent
```

## `package:tandem/testing.dart`

```dart
typedef AgentTurn = List<AgentStep> Function(RunRequest request);

/// An in-memory AgentConnection that plays one turn per run, with no network.
/// With mimicAdk (default) it behaves like ag-ui-adk: no parentMessageId, no
/// ARGS for empty arguments, STATE_SNAPSHOT with server keys between the last
/// tool call's ARGS and END, state changes as whole top-level values, a
/// snapshot at the end of every run, a shallow per-key merge of the app's
/// state at run start. With checkProtocol (default) a request that breaks an
/// AG-UI rule gets RUN_ERROR PROTOCOL_VIOLATION; a run beyond the script gets
/// RUN_ERROR SCRIPT_EXHAUSTED. Events are sent in microtasks, so
/// pumpAndSettle drains a run.
final class ScriptedAgent implements AgentConnection {
  ScriptedAgent(List<AgentTurn> turns, {bool mimicAdk = true, bool checkProtocol = true});
  List<RunRequest> get requests;
  bool get isExhausted;
}

final class RunRequest {
  RunInput get input;
  String? get userText;
  Map<String, Object?> get state;
  S stateAs<S>(StateCodec<S> codec, S current);
  Map<String, Object?>? resultOf(String toolName); // decoded tool message new in this run
  List<String> get reportedUserEdits;
}

final class AgentStep {
  const AgentStep.say(String text);
  const AgentStep.runAgentTool(String name, {Map<String, Object?> args = const {}, Object? result});
  const AgentStep.callTool(String name, [Map<String, Object?> args = const {}]);
  const AgentStep.setState(Map<String, Object?> state);              // STATE_SNAPSHOT
  const AgentStep.patchState(List<Map<String, Object?>> operations); // STATE_DELTA
  const AgentStep.waitFor(Future<void> signal);                      // pause mid-run, e.g. to type during a run
  const AgentStep.fail(String message, {String? code});              // RUN_ERROR
  const AgentStep.event(Map<String, Object?> json);                  // anything, including unknown types
}
```

## `package:tandem_bloc/tandem_bloc.dart`

```dart
/// Makes an existing Cubit or Bloc the state host. Nothing to implement.
/// On a Bloc, agent writes bypass event handlers.
mixin AgentEditable<S> on BlocBase<S> implements StateHost<S> {
  @override
  void writeFromAgent(S value) => emit(value);
}

/// The session's view as a Cubit. Not generic. close() disposes the session
/// before anything else, so the session never writes into a closed host.
class TandemCubit extends Cubit<TandemView> {
  TandemCubit(TandemSession<Object?> session);
  TandemSession<Object?> get session;
  Future<void> send(String text);
  Future<void> stop();
}

/// Makes the screen below agent-aware. Put it under the BlocProvider of C.
/// [connection] defaults to context.read<AgentConnection>(); a clear assert
/// explains how to provide it when it is missing. codec, tools and options are
/// read once, when the session is created.
class TandemScope<C extends StateHost<S>, S> extends StatelessWidget {
  const TandemScope({
    super.key,
    required this.codec,
    required this.child,
    this.tools,
    this.connection,
    this.options = const TandemOptions(),
  });
  final StateCodec<S> codec;
  final List<Tool<S>> Function(BuildContext context)? tools;
  final AgentConnection? connection;
  final TandemOptions options;
  final Widget child;
}
```

## Behaviour behind the interface

### Shared state

- Tandem keeps the agent's full document, server keys included, so JSON Patch paths stay valid.
  `STATE_SNAPSHOT` replaces it, `STATE_DELTA` applies RFC 6902 (Tandem's own implementation). A patch
  that fails is ignored and reported as a diagnostic.
- **Conflicts: last write wins, per leaf.** An agent write is the set of leaves in the owned keys that
  differ from what the agent already had: what Tandem sent at run start plus the earlier events of that
  run. Restating unchanged values is not a write, so ADK's end-of-run snapshot does not revert a value
  the user typed during the run. A list whose length changed is replaced as a whole.
- An agent write is merged into `encode(host.state)`, decoded with `decode(current, doc)` and passed to
  `host.writeFromAgent`.
- **User edits are told from echoes by content.** Tandem keeps every value it wrote that has not been
  echoed yet; a host value that matches none of them and differs from the last known state is a user
  edit. A user edit clears the marks of the edited leaves, makes pending approval requests stale and,
  with `reportUserEdits`, is listed in the context of the next run.
- The run input `state` is `codec.encode(host.state)` and nothing else. Server keys (`_ag_ui_*`,
  `pending_tool_calls`) are never sent. Whole top-level values are always sent, because ag-ui-adk
  merges shallowly per key.
- When a list taken whole reverts a user edit, the agent is the last writer of that leaf: it is marked,
  and the edit is no longer reported.
- An asynchronous host (bloc) delivers an edit in a later microtask. When a run starts or ends, Tandem
  reads `host.state` and takes an edit it has not seen yet into account at once, so an edit made in the
  same handler as `send` is reported in that run.

### Runs and history

- Same `threadId` for the session, a new `runId` (UUID v4) per run. `tools` is always sent, `[]` when
  there are none. `forwardedProps` is `{}`. The full history is sent every time.
- At most one run at a time. `send` during a run queues the message and cancels further automatic
  follow-ups; the message goes out with the next run, after the tool answers.
- A tool call without `parentMessageId` gets a synthesized assistant message with id `asst-<toolCallId>`;
  the tool call id itself is never a message id. `TOOL_CALL_RESULT` becomes a tool message with its own
  `messageId`. Answers of tools get id `tool-<uuid>`. `MESSAGES_SNAPSHOT` replaces the history, not the
  timeline.
- Tolerated: `RUN_ERROR` without `RUN_STARTED`; any event while a tool call is open; a call without
  ARGS (arguments `{}`); `TEXT_MESSAGE_CHUNK` and `TOOL_CALL_CHUNK` (expanded); unknown types (ignored,
  diagnostic); a stream that ends without `RUN_FINISHED` (treated as finished).
- After a run ends, every completed call of a registered tool without a result is handled: tools without
  approval run one after another in call order; tools with `needsApproval` become a pending approval
  request whose reference state is `encode(host.state)` after all of that run's state events. If the user
  edited the shared state during that run and the agent did not overwrite the edit, the request starts
  stale: the agent proposed without seeing it. Agent tools show running until `TOOL_CALL_RESULT`; a
  failed run marks them failed.
- Follow-ups: when results exist and no approval request is open, one automatic follow-up run carries all
  of them. While requests are open nothing runs; when the last one is resolved, one follow-up carries all
  held results and outcomes.
- Every tool call of the previous run is answered before or together with the next user message; tool
  messages come first.
- Loop guard: at most `maxAutoRuns` follow-ups in a row triggered only by tool calls. `send`, `approve`
  and `reject` reset the count. When exceeded, no run starts, `error.kind` is `loopGuard`, and the results
  wait for the next `send` or `retry`.

### Approval requests (minimal semantics for the spike)

- A pending request becomes stale as soon as `encode(host.state)` differs from its reference state,
  whoever changed it. Stale is terminal.
- `approve` is a no-op unless pending, so double taps are harmless. It re-checks the state synchronously,
  then: executing, `run(call)` with `call.state` = the approved state, then executed or failed.
- `reject` works on pending or stale.
- `send` while requests are open: pending ones become dismissed, stale ones are answered as invalidated
  (both end as `dismissed`). A message queued during the run that proposes counts as sent while pending.
- A complete call of a tool with `needsApproval` in a run that is stopped or fails shows as a `dismissed`
  request, so the user still sees what the agent proposed; the agent gets `cancelled`.

Payloads the agent receives (tool message content, JSON):

| Situation | Payload |
|---|---|
| tool returned | `{"status":"ok","result":...}` |
| tool threw or arguments invalid | `{"status":"error","error":"..."}` |
| approved and executed | `{"status":"executed","approved":true,"result":...}` |
| approved, run threw | `{"status":"failed","approved":true,"error":"..."}` |
| rejected | `{"status":"rejected","approved":false}` |
| user chatted while pending | `{"status":"dismissed","approved":false,"reason":"user_sent_message"}` |
| user chatted while stale | `{"status":"invalidated","approved":false,"reason":"state_changed"}` |
| run stopped | `{"status":"cancelled"}` |

### Errors

- `send` never throws for run failures; it throws `StateError` after dispose.
- `connection`: non-2xx (status and body in the message), a 2xx answer that is not
  `text/event-stream` (usually a wrong URL), idle timeout (also for a `headers` callback that does not
  complete), socket or stream errors.
  `agent`: `RUN_ERROR` with its code. `loopGuard`: see above. `retry` resends what was not delivered;
  safe because the backend skips messages it already processed. That is also why it cannot recover an
  answer lost after `RUN_STARTED`: ag-ui-adk answers a retry that brings nothing new with an empty
  `RUN_STARTED`/`RUN_FINISHED` pair. Tandem then shows an error that says the answer is lost and a new
  message is needed.
- A tool that throws, or arguments that do not match its params: the agent gets the error payload, the
  activity shows failed, the session continues.
- `stop` cancels the subscription, which closes the run's HTTP client. It only stops receiving: an AG-UI
  backend may still finish the run on its side, agent tools included. Calls the stopped run completed
  are answered as cancelled with the next run; half-received calls are dropped. A failed run is handled
  the same way. A tool already running in the app finishes and its result goes out with the next run;
  the tools waiting after it are answered as cancelled at once, whatever the user does next. Messages
  queued during the run are the user's turn, not a follow-up: they go out at once, with those answers.

## Deferred (known, not in the spike)

From the critics, in order of importance:

1. Approvals guard a tool call, not writes to the shared state: the agent can write a value directly that
   would need approval through a tool. Planned: guarded paths in the codec.
2. A tool that changes the shared state is seen as a user edit (stales sibling requests). Planned:
   `ToolCall.update(...)` that writes as the agent.
3. Lists addressed by index: an agent removing a line shifts marks and merges. Planned: keyed lists
   (`listKeys: {'lines': 'sku'}`).
4. Staleness is global: typing in notes makes an order approval stale. Planned: scoped staleness.
5. Conditional approval (`needsApproval: (call) => ...`).
6. Ready-made widgets in tandem_bloc (timeline, approval card builder, `AgentHighlight`).
7. AG-UI 1.0 interrupts and `resume`, `RUN_FINISHED.outcome`, persistence of sessions, Riverpod adapter.
8. ADK-native confirmation (`FunctionTool(require_confirmation=True)`) is not supported. The timeline
   then shows the agent tool as succeeded (Tandem does not read agent tool results, and ADK answers
   with an error asking for confirmation), and `adk_request_confirmation` as running for good. Use a
   tool with `needsApproval` instead.

## Open naming questions

- `AgentEditable`, `AgentMarks`, `AgentConnection`, `AgentMessage` keep the `Agent` word because they
  name the agent's side; session-level types use `Tandem` (`TandemSession`, `TandemView`, `TandemCubit`,
  `TandemScope`, `TandemOptions`, `TandemError`). OK?
- `Tool` is a common word; collisions with other AI packages are possible. Keep, or `TandemTool`?
