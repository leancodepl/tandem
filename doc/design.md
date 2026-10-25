# Tandem design

Vocabulary: [GLOSSARY.md](../GLOSSARY.md). Decisions: [ADR 0001](adr/0001-own-protocol-model-behind-agent-connection.md) and [ADR 0002](adr/0002-agent-acts-only-through-listed-methods.md).

## Packages

| Package | Owns | Depends on |
|---|---|---|
| `tandem` | the agent list, remote and Apple AG-UI connections, the session, `TandemScope`, `TandemBridge`, `ScriptedAgent` | flutter, http, meta, uuid; FoundationModels on Apple systems |
| `tandem_generator` | the builder that turns the `agentCapabilities` of a class with `@TandemAgent()` into code | analyzer, build, build_config, source_gen |

`tandem` depends on no state library. `TandemScope` reads the state object with its `surface` closure, and the object reports its own changes in `changes`, so a state library needs no adapter package.

`tandem` has no widget the user sees. The app builds its chat on `TandemSession`, which it reads with `TandemSessionScope.of`, so the texts, their language and the look are the app's. The example's `AgentChat` is one to copy.

The repo root is a pub workspace, not a package. Its `pubspec.lock` is committed, so development and CI resolve the same versions. The workspace members have no lock of their own.

`tandem_generator` is not a workspace member: its dev dependency `test` needs a `test_api` that the pin of `flutter_test` rules out. It has its own lock, which is not committed. The example depends on it by path, and CI runs `dart pub get` in it.

The generated mixin implements `AgentSurface` of `tandem` and builds its `AgentSchema` from `AgentView.of` and `AgentTool`, reading the agent's arguments with `ToolArgs`. So both packages release together, with the same minor version. The generator cannot depend on `tandem`, which needs Flutter.

`packages/tandem/README.md`, the README pub.dev shows for `tandem`, is a copy of the root README with one difference: under "Try it without a key", GitHub plays the demo film and pub.dev, which plays no video, shows it as a GIF. Change both.

`tandem` ships three Agent Skills in `skills/`, which apps install with `dart run skills@ get --package tandem --all`: `tandem-agent-aware-screen` lists what the agent sees and calls and wraps the screen, `tandem-coding-agent` lets a coding agent drive it through `TandemBridge`, and `tandem-in-app-agent` adds a chat or a button with a backend or Apple's model. The installer takes only skills whose name starts with `tandem-`. The skills follow the API: change one, change the other.

`skills/tandem` at the repo root is the entry, `/tandem`, which apps install from GitHub with `dart run skills@ add leancodepl/tandem --skill tandem`. It follows `main`, not the app's version of `tandem`, so it only checks the packages, installs the package's skills of the version in `pubspec.lock` and hands the work to them. It needs `user-invocable: true`, or the installer marks it `false` and `/tandem` does not run.

The README and both packages' `example/example.md` show only code from `example`, and `example/test/doc_snippets_test.dart` checks each Dart block against the file its comment names. `example` has two examples in one app: the order desk on bloc with a scripted agent, and the invoice list on provider with Apple's on-device model. Only the example depends on bloc and provider.

## Session rules

- Every run reads the live list: `context` from `.sees`, `tools` from `.calls`. Every tool call checks the list again.
- One run at a time in a thread. A message sent meanwhile shows at once and goes with the next run. Several go as one, the texts joined by a blank line.
- `session.note(text)` keeps the latest five notes of the app, and every run gives them as the last `context` entry, `app_notes`: `{"new": [...], "earlier": [...]}`, new until a run that offered them finished. `context` does not stay in the history of every backend, so every run sends the earlier ones again. A note changes no status and no item, and does not count as a change of `.sees`.
- `session.wake()` posts a `UserMessage` with `fromApp`, a fixed text that says the app sent it. It never decides for the user: it starts a run only once the session is idle and no request waits, and after a Stop it waits for the user's next message. Any run that starts before takes it along.
- `status` follows from the open run: `Stopping` once the user stopped it, `Calling` while a listed method runs, else `Thinking`. `Thinking` names a tool of the backend from its `TOOL_CALL_START` until its `TOOL_CALL_RESULT` or the agent's next text, the latest one when several run. Without a run it is `AwaitingApproval` with the request that shows, or `Idle`.
- A call without approval runs at once, and its result goes in the next run.
- The session tells `onEvent` what happened, as a sealed `TandemEvent`: an `AgentCall` after every call of a listed method that returned, including approved ones, with the name, arguments, result and caller; `RunStopped` on every Stop that stops a run, and when the backend cancels one; `RunFailed`, with the error's `RunErrorCode` when it has one, and `ConnectionLost`, which also add a `ChatNotice`. A Stop adds a notice too or marks the last message `stopped`. Each event comes once the session has settled and notified, so `onEvent` may send a message at once. `TandemScope` passes its own context and the session that sent the event, so an app can read what is provided above it, such as the surface, highlight the changed fields or show a snackbar. Approval requests are not events: they go to `approvals:`. The events need no context, so a `session.events` stream of the same types can come later.
- A call that needs approval shows a card with a frozen copy of its arguments and keeps a snapshot of `.sees`, taken after the turn's calls without approval ran. Every event of the surface's `changes` compares `.sees` with the snapshot, and a difference invalidates the card for good. An event that comes late or changes nothing in `.sees` does no harm, so the card shows at once. A change undone before the session hears of it goes unseen (A, B, A). Approve compares again, for values `changes` does not report. When `.sees` changed after the run started, compared with what the run sent, the turn's requests are invalidated before they show, and the answers go at once. This covers a change while the agent thought and one made by a call of the same turn: the agent asks again in its next run. A `.sees` that cannot be read counts as changed, and the error is reported.
- Several calls in one turn: those without approval run first. Those with approval show one at a time, in order: the next once the previous one is decided and, when approved, its method returned. An approved method that changes `.sees` invalidates the rest, and Reject cancels the rest, so the agent plans again. A request that never showed gets only its answer. One run carries all the answers, and it starts when every call of the turn has one. A message queued meanwhile goes in the same run, after the answers. A run with only the answers starts only when nothing is queued.
- `approve` and `reject` decide the request that shows. The same decision again does nothing. Any other throws `ApprovalNotPending`: approving a request that was rejected, cancelled or invalidated, or whose `.sees` changed, which invalidates it, and rejecting one that was approved, cancelled or invalidated.
- A `changes` event that invalidates the request that shows starts no run: `invalidated` goes with the user's next message.
- `approvals:` on `TandemScope`: `.callback` gets each request when it shows, once the session waits for it, with the scope's context. A request it leaves undecided stays pending until the user's next message cancels it. `.fromState()` leaves the requests to the UI. `.none()` refuses every call that needs approval and reports it in debug, so the agent does not wait for nothing.
- **Stop does not cancel the run.** Cancelling does not stop ADK: the model keeps generating, the answer lands in the server's session, and a run sent right after mixes up the history. Stop hides the rest of the text and drains the run: it reads the stream to `RUN_FINISHED` or `RUN_ERROR`.
- After Stop, the text already shown stays, marked `stopped`, and only that text goes back in the history. None of its remaining calls runs. Until the run ends the status is `Stopping` and a new message waits.
- An approved method runs to its end, as `Calling` with `approved`, and Stop does nothing until it returns. Tandem cannot interrupt the app's code, and a request the method already sent stays sent.
- Before each new user message, every call without an answer is answered, all in one run, the message last. Executed: the real result. Not executed (Stop, or the user wrote instead of deciding): `cancelled`. Invalidated: `invalidated`. The status goes in `content`, because the middleware ignores `error` and the model reads an empty `content` as success. AG-UI 1.0 also wants every call answered before the thread goes on.
- `RUN_FINISHED` or `RUN_ERROR` ends the run's stream and closes the connection, even when the server keeps it open. The session cancels an unfinished stream only when it is disposed, when the stream fails, which breaks the run, or when an event fails the run. The cancel aborts a request that still waits for its response headers, and completes once the connection is cleaned up.
- A run is never sent twice: the server would answer with an empty `RUN_STARTED`/`RUN_FINISHED` pair.
- A run that breaks without a final event adds a `connectionLost` notice, and the next message starts a new thread with fresh history.
- `session.startOver()` moves the chat to a new thread when the app asks, such as when the history no longer fits the model. Requests that wait are cancelled, the items stay and a `startedOver` notice shows. It does nothing while a run is open, as Stop does nothing in the wrong state.
- A `RUN_FINISHED` with the outcome `cancelled` stops the run as Stop does, with its notice and `RunStopped`: none of its calls runs, and they go to the agent as `cancelled` with the next run. An `interrupt`, which Tandem cannot follow, or an outcome of the wrong shape fails the run without running its calls, and the next message starts a new thread whose user message also holds the messages queued meanwhile. No outcome, `outcome: null` or an outcome of another type is success: AG-UI 1.0 drops an outcome type it does not know, and older SDKs send `null`.
- No response headers or no bytes for 60 s counts as a broken run. ADK pings every 15 s, but the parser drops comments, so the timeout watches the raw bytes.
- `TandemScope` opens one session, and an ordinary rebuild keeps it. A new session with a new thread replaces it when `agent` is another `Uri` (`==`) or `connected` gets another connection (`identical`). The old session is disposed first. Each new session calls `surface` again with the scope's context. Another object from the provider under the same scope opens no session. A scope without `agent` runs over a connection whose every run ends with `RUN_ERROR`, so `send` reports what is missing. A scope that leaves the tree disposes its session before the owner of the state object, such as a `BlocProvider`, closes it. A new `onEvent` or `approvals` takes effect at once.
- `threadId` lives as long as its session and never comes back after it is gone: an orphaned ADK run would mix up the history.
- A run error shows in the chat, and the next message works as usual. Its code and message, like every error the session catches, go to `FlutterError.reportError`, never to the chat.

## Coding agent

A coding agent, such as Claude Code or Cursor, drives a debug build through the Dart MCP server and `TandemBridge`. `TandemBridge.enable()` in `main()` registers the VM service extensions `ext.tandem.describe` and `ext.tandem.call`, once per isolate. An extension cannot be unregistered, so one line switches the whole app, not a parameter of each scope. Outside `kDebugMode` it does nothing, and the compiler drops the extensions.

- Every `TandemScope` of a debug build is an open screen, also without `enable()` and without `agent`, so a test needs no setup. Its id is the class name of its surface, numbered when taken: `Shop`, `Shop#2`.
- A call without `screen` goes to the front screen: the only one open, or else the only one whose route is current (`ModalRoute.isCurrentOf`). A scope outside any route counts as on the current one. Tabs of an `IndexedStack` share a route, so a call names its screen.
- `describe` gives every open screen as the in-app agent would get it: `sees` is the AG-UI `context` and `tools` the AG-UI `tools`, plus `needsApproval`. Every answer of `call` has them too, read after the call.
- A call checks the live list, as the in-app agent's calls do, and `onEvent` hears an `AgentCall` once the method returned. The call stays out of the AG-UI thread: the in-app agent sees its effect in `.sees` on its next run.
- `TandemBridge.describe()` and `TandemBridge.call()` give the JSON of the extensions as Dart values. An agent list that the generated code no longer fits throws a `StateError`, as in a run, and the extension answers with that error, so the coding agent can run build_runner.
- A call of a `.callsWithApproval` method waits for the user as an `ApprovalRequest` in `session.items`, in a turn of its own: `AwaitingApproval`, `.callback` with the scope's context, `approve` and `reject`, as for the in-app agent. It shows once the session is idle, so the in-app agent's requests show first. A change to `.sees` invalidates it, a message of the user cancels it once it shows, and `startOver` and dispose cancel it. An approved method runs as `Calling` with `approved`, and a message sent meanwhile waits for it.
- Its answer goes only to the coding agent. The request never goes to the in-app agent's history, and its decision starts no run: the in-app agent's own answers still wait for the user's next message.
- One request of a coding agent waits at a time. The same call, the same tool with the same arguments, waits for the same answer, so a client that timed out and calls again gets the user's decision. Another call that needs approval is refused until then.
- A client can stop waiting before the user decides, some after 60 s, and the method still runs once the user approves. `describe` shows the last request of each screen as `lastApproval`: `pending` while the user decides, `approved` while the method runs, then its answer. The coding agent reads it before it calls again.
- `TandemBridge.enable(autoApprove: true)` runs such a call at once without a request, also on a screen with `approvals: .none()`, for automation. Without it, a screen with `.none()` refuses the call with a reason that names the option.

Every answer of `call` is a `ToolAnswer` as `json`: the tool answer of the in-app agent with its `status`, and `{"status":"returned","result":<result>}` when the method returned. No screen, an unknown `screen` or no front screen is `refused`, with the ids of the open screens. So is another call that needs approval while one waits, and one on a screen with `approvals: .none()`, with what to do.

## Apple on-device connection

`OnDeviceAgent.apple()` is an `AgentConnection` backed by a plugin inside `tandem`, with shared Darwin sources for SwiftPM and CocoaPods. Dart and Swift talk through the Pigeon API of `packages/tandem/pigeons/apple_api.dart`: the run's AG-UI body goes as JSON, and the answer comes back as text, a batch of calls or a failure code. `apple()` returns one immutable object, so a scope keeps its session across rebuilds. Each run gets its own request ID, native task and model session, so sharing the connection shares no conversation. Tandem keeps the history, context, execution and approvals.

Dart builds the instructions for every run from the current tools and context (`on_device_instructions.dart`). They stay short for the 4096-token window. Swift turns the AG-UI history into Apple's transcript: consecutive assistant calls form one batch, every call needs its result, and the last user message becomes the prompt. A run that ends with tool results has no prompt.

**Handoff.** Native tool callbacks never run app methods. The first callback copies the model's whole batch from the transcript and throws a private error; its siblings check that they belong to that batch. Only that error turns into proposed calls. Dart then checks the batch (`_RunInput.wholeBatch`): every call must be a current tool with object arguments and an ID unused in the batch and the history, or none runs and the run fails. A remote turn would run its other calls, but here an odd call means the batch was read wrong. Tandem runs the calls with its usual checks and approvals.

The copy relies on when Apple writes the batch to the transcript. That timing was measured on macOS 26.6.2 and iOS 26.6.1 and is not documented. Native probes passed all 36 handoff cases on a physical Mac and iPhone, but they cannot prove that no sibling is missing. The model can also propose a wrong current call, so app validation and approvals stay responsible.

**Schemas.** Tool schemas go through `GenerationSchema`'s Codable form. It takes `type`, `description`, `properties`, `required`, `items`, string `enum` and `anyOf`, which is everything `tandem_generator` writes except `format`. Any other keyword, such as the `format` of a `DateTime`, fails the run with `OnDeviceErrorCode.unsupportedSchema` instead of being dropped. iOS 26.2 rejects a union with null, which macOS 26.6.2 takes. Then every property that may be null becomes optional, and `ToolArgs` reads an omitted one as null, so the method gets the same value. A null union inside an array item still fails. Only the schema step of this was checked, on the iOS 26.2 simulator, whose model does not generate.

**Numbers.** Apple keeps numbers as `Double`. Integral arguments beyond ±(2^53 - 1), in the history or new, fail with `OnDeviceErrorCode.unsupportedArguments` instead of being rounded.

**Ending a run.** The text arrives whole when generation ends. Stop drains the run and runs none of its calls. Disposing the session cancels the native task and waits for it to end. Nothing retries, summarizes or shortens the history: an overflow fails with `OnDeviceErrorCode.contextWindowExceeded`, and the app may call `session.startOver()`. Other native failures keep their own `OnDeviceErrorCode`.

`bash tool/check_apple.sh` runs the native contracts without inference, by hand: CI has no macOS runner. `tool/apple_smoke.swift --generate` asks the real model and stays manual.

## Wire rules

For ag-ui-adk 0.9.0. Its behaviour differs between versions.

- POST with `Accept: text/event-stream` and `Content-Type: application/json`.
- Body `{threadId, runId, state: {}, messages, tools, context, forwardedProps: {}}`. `tools` is always there, `[]` when empty. No `resume`, no `protocolVersion`.
- User message: `{id, role: 'user', content}`. What the user and `session.wake` sent since the last run went out goes as one message, the texts joined by a blank line: ag-ui-adk passes the model only the last new user message of a run.
- Assistant text: `{id: <TEXT_MESSAGE_START messageId>, role: 'assistant', content: <visible text>}`.
- App tool call: `{id: 'asst-<toolCallId>', role: 'assistant', toolCalls: [{id: <toolCallId>, type: 'function', function: {name, arguments}}]}`. `arguments` is the joined `TOOL_CALL_ARGS`, or `'{}'`: ag-ui-adk sends none for a call without arguments. The message id is never the bare call id, or ag-ui-adk would swallow the answer as processed.
- Tool answer: `{id: 'tool-<toolCallId>', role: 'tool', toolCallId, content: <JSON string>}`, no `error` field.
- Order inside one run: assistant text, the `asst-` messages of the turn, all tool answers, the user message last.
- `context`: one `{description: '<name>: <doc comment>', value: <JSON string>}` per `.sees`, then the `app_notes` entry once the app wrote a note.
- A `TOOL_CALL_START` whose name is not in this run's `tools` is a backend tool. It is ignored, never executed, never echoed.
- A `TOOL_CALL_START` with the id of a call the run already has keeps the first start. With another name it fails the run.
- A response may replay earlier runs before the requested one. Events before the `RUN_STARTED` of the requested `runId` and `threadId` are skipped. A `RUN_ERROR` before any `RUN_STARTED` still ends the stream, unless it names another thread or run.
- `TEXT_MESSAGE_CHUNK` and `TOOL_CALL_CHUNK` are rewritten while decoding as the content, start and args events they abbreviate, so the session reads one form.
  - As in AG-UI, a new id opens a message or call, and no id continues the open one of the chunk's sender: the subagent its `subagentRunId` names, or the parent.
  - A sender has one stream open at a time. Opening a message, a call or a reasoning message (`REASONING_MESSAGE_CHUNK`, which passes through) closes the one it had. Its other text, call, state, step, reasoning and custom events close it too. `SUBAGENT_FINISHED` and `SUBAGENT_ERROR` close the one of their subagent, and a run event or `MESSAGES_SNAPSHOT` closes them all.
  - A chunk with neither id nor `subagentRunId` continues the parent's open message or call, else the only one open in a subagent. When several subagents have one open, the chunk fails the stream like malformed JSON, so the run counts as broken: the client does not know where the chunk goes, and the server's run may go on.
  - A chunk that belongs to nothing, or opens a call without its name, is dropped.

## Tool answers

The `content` of the tool message, built in `session/tool_answer.dart`.

| Situation | Content |
|---|---|
| executed | `jsonEncode(result)`, `null` for `void` |
| refused: not listed at call time, needs approval, the screen takes no approvals, bad arguments, or the method threw a `ToolCallRefused` | `{"status":"refused","reason":<message>}` |
| the method threw anything else | `{"status":"failed","error":<fixed message>}` |
| the method returned, but `jsonEncode` failed on its result | `{"status":"result_unavailable","reason":<fixed message>}` |
| Reject | `{"status":"rejected_by_user"}` |
| not executed, or the user wrote instead of deciding | `{"status":"cancelled"}` |
| invalidated | `{"status":"invalidated","reason":<fixed message>}` |

Only a `ToolCallRefused` gives the agent its message. Any other error of a method, an `ArgumentError` too, goes only to `FlutterError.reportError`.

`rejected_by_user`, not `rejected`: Gemini answers a plain `rejected` as if the system refused the call.

## Deferred

- AG-UI interrupts.
- Telling a message the app sent with `session.send` from one the user wrote. Both are a `UserMessage` without `fromApp`, which only `session.wake` sets ([RFC 0001](rfc/0001-core-without-ui-and-state-libraries.md#events-and-status), decision 15).
- Several state objects per screen, a conversation across screens, and `session.events` ([RFC 0001](rfc/0001-core-without-ui-and-state-libraries.md#later-not-in-pre-v1)).
- Resync of a broken run through the experimental `/agents/state`.
- A loop guard, if a real model loops.
- `additionalProperties: false` in the schemas, once Gemini accepts it.
- Publishing from CI. pub.dev takes automated publishing only for a package that exists, so the first release of each package goes up by hand.
