# Tandem design

Vocabulary: [GLOSSARY.md](../GLOSSARY.md). Decisions: [ADR 0001](adr/0001-own-protocol-model-behind-agent-connection.md) and [ADR 0002](adr/0002-agent-acts-only-through-listed-methods.md).

## Packages

| Package | Owns | Depends on |
|---|---|---|
| `tandem` | the agent list, the AG-UI connection, the session, `TandemChat`, `ScriptedAgent` | flutter, http |
| `tandem_bloc` | `TandemScope<C>`: takes the cubit from the context, invalidates approvals on its `stream`, passes `onAgentCall`; exports `tandem` | tandem, flutter_bloc |
| `tandem_generator` | the builder that turns the `agentCapabilities` of a class with `@TandemAgent()` into code | analyzer, build, source_gen |

`tandem` does not depend on bloc. Riverpod support would be a separate `tandem_riverpod` with its own `TandemScope`.

`TandemChat` fills its parent: the app decides where it goes and how wide it is.

The repo root is a pub workspace, not a package. Its `pubspec.lock` is committed, so development and CI resolve the same versions. The workspace members have no lock of their own.

`tandem_generator` is not a workspace member: its dev dependency `test` needs a `test_api` that the pin of `flutter_test` rules out. It has its own lock, which is not committed. The example depends on it by path, and CI runs `dart pub get` in it.

`packages/tandem_bloc/README.md`, the README pub.dev shows for `tandem_bloc`, is an identical copy of the root README. Change both.

`tandem_bloc` ships an Agent Skill, `skills/tandem-bloc-agent-aware-screen`, that apps install with `dart run skills@ get`. It follows the API: change one, change the other.

## Session rules

- Every run reads the live list: `context` from `.sees`, `tools` from `.calls`. Every tool call checks the list again.
- One run at a time in a thread. A message sent meanwhile shows at once and goes with the next run.
- A call without approval runs at once, and its result goes in the next run.
- After every call of a listed method that returned, including approved ones, the session calls `onAgentCall` with an `AgentCall`: the name, arguments and result. `TandemScope` passes it a context below the `BlocProvider`, so an app can read the cubit and highlight the changed fields.
- A call that needs approval shows a card with a frozen copy of its arguments. Any emission of `changes` after the card shows invalidates it for good, even when the state comes back (A, B, A), which comparing the latest value would miss. `.sees` is captured after the turn's calls without approval ran, and the card shows one event-loop turn later, so what those calls emitted arrives first and invalidates nothing. Approve compares `.sees` again, for values `changes` does not report.
- Several calls in one turn, one of them with approval: the others run first, then the card freezes. One run carries all the answers, and it starts when every call of the turn has one. A message queued meanwhile goes in the same run, after the answers. A run with only the answers starts only when nothing is queued.
- Reject answers its call at once. Invalidation does not start a run: `invalidated` goes with the user's next message.
- **Stop does not cancel the run.** Cancelling does not stop ADK: the model keeps generating, the answer lands in the server's session, and a run sent right after mixes up the history. Stop hides the rest of the text and drains the run: it reads the stream to `RUN_FINISHED` or `RUN_ERROR`.
- After Stop, the text already shown stays, marked "Stopped", and only that text goes back in the history. None of its remaining calls runs. Until the run ends the chat shows "Stopping…" and a new message waits.
- Before each new user message, every call without an answer is answered, all in one run, the message last. Executed: the real result. Not executed (Stop, or the user wrote instead of deciding): `cancelled`. Invalidated: `invalidated`. The status goes in `content`, because the middleware ignores `error` and the model reads an empty `content` as success. AG-UI 1.0 also wants every call answered before the thread goes on.
- `RUN_FINISHED` or `RUN_ERROR` ends the run's stream and closes the connection, even when the server keeps it open. The session cancels an unfinished stream only when it is disposed, or when the stream fails, which breaks the run. The cancel aborts a request that still waits for its response headers, and completes once the connection is cleaned up.
- A run is never sent twice: the server would answer with an empty `RUN_STARTED`/`RUN_FINISHED` pair.
- A run that breaks without a final event shows "Connection lost" and the next message starts a new thread with fresh history.
- No response headers or no bytes for 60 s counts as a broken run. ADK pings every 15 s, but the parser drops comments, so the timeout watches the raw bytes.
- `TandemScope` opens one session, and an ordinary rebuild keeps it. A new session with a new thread replaces it when the provider gives another cubit, `agent` is another `Uri` (`==`), or `connected` gets another connection (`identical`). The old session is disposed first. A scope that leaves the tree disposes its session before the `BlocProvider` closes the cubit. A new `onAgentCall` takes effect at once.
- `threadId` lives as long as its session and never comes back after it is gone: an orphaned ADK run would mix up the history.
- A run error shows in the chat, and the next message works as usual. Its code and message, like every error the session catches, go to `FlutterError.reportError`, never to the chat.

## Wire rules

For ag-ui-adk 0.9.0. Its behaviour differs between versions.

- POST with `Accept: text/event-stream` and `Content-Type: application/json`.
- Body `{threadId, runId, state: {}, messages, tools, context, forwardedProps: {}}`. `tools` is always there, `[]` when empty. No `resume`, no `protocolVersion`.
- User message: `{id, role: 'user', content}`.
- Assistant text: `{id: <TEXT_MESSAGE_START messageId>, role: 'assistant', content: <visible text>}`.
- App tool call: `{id: 'asst-<toolCallId>', role: 'assistant', toolCalls: [{id: <toolCallId>, type: 'function', function: {name, arguments}}]}`. `arguments` is the joined `TOOL_CALL_ARGS`, or `'{}'`: ag-ui-adk sends none for a call without arguments. The message id is never the bare call id, or ag-ui-adk would swallow the answer as processed.
- Tool answer: `{id: 'tool-<toolCallId>', role: 'tool', toolCallId, content: <JSON string>}`, no `error` field.
- Order inside one run: assistant text, the `asst-` messages of the turn, all tool answers, the user message last.
- `context`: one `{description: '<name>: <doc comment>', value: <JSON string>}` per `.sees`.
- A `TOOL_CALL_START` whose name is not in this run's `tools` is a backend tool. It is ignored, never executed, never echoed.
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
| refused: not listed at call time, needs approval, bad arguments, or the method threw an `ArgumentError` other than a `RangeError` | `{"status":"refused","reason":<message>}` |
| the method threw anything else | `{"status":"failed","error":<toString>}` |
| Reject | `{"status":"rejected_by_user"}` |
| not executed, or the user wrote instead of deciding | `{"status":"cancelled"}` |
| invalidated | `{"status":"invalidated"}` |

`rejected_by_user`, not `rejected`: Gemini answers a plain `rejected` as if the system refused the call.

## Deferred

- Riverpod.
- AG-UI interrupts.
- Resync of a broken run through the experimental `/agents/state`.
- A loop guard, if a real model loops.
- l10n: the UI strings are hard-coded in English.
- `additionalProperties: false` in the schemas, once Gemini accepts it.
- Publishing: `publish.yml` runs by hand only, because it publishes the repo root, which is not a package. Each of the three packages needs its own release, `tandem` first.
