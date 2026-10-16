# Tandem: design

Vocabulary: [GLOSSARY.md](../GLOSSARY.md). Decisions: [ADR 0001](adr/0001-own-protocol-model-behind-agent-connection.md) and [ADR 0003](adr/0003-agent-acts-only-through-listed-methods.md). [ADR 0002](adr/0002-attach-to-the-apps-state-host.md) is superseded.

## Packages

| Package | Owns | Depends on |
|---|---|---|
| `tandem` | the agent list, the AG-UI connection, the session, `TandemChat`, `ScriptedAgent` | flutter, http |
| `tandem_bloc` | `TandemScope<C>`: takes the cubit from the context, invalidates approvals on its `stream`, passes `onAgentCall`; exports `tandem` | tandem, flutter_bloc |
| `tandem_generator` | the builder that turns a cubit's `agent` list into code | analyzer, build, source_gen |

`tandem` does not know bloc. Riverpod would be a separate `tandem_riverpod` with its own `TandemScope`.

The repo root is a workspace, not a package. `tandem_generator` is not a member: its dev dependency `test` needs a `test_api` that the pin of `flutter_test` rules out. It has its own lock, the example depends on it by path, and CI runs `dart pub get` in it.

The root README and `packages/tandem_bloc/README.md` are the same file.

## Session rules

- Every run reads the live list: `context` from `.sees`, `tools` from `.calls`. Every tool call checks the list again.
- One run at a time in a thread. A new message waits until the run ends.
- A call without approval runs at once, and its result goes in the next run.
- After every call of a listed method that returned, also an approved one, the session calls `onAgentCall` with the name, arguments and result. The demo highlights changed fields from it.
- A call with approval shows a card with frozen arguments (a copy). A change of anything in `.sees` invalidates the card for good.
- Several calls in one turn, one of them with approval: the ones without run first, then the card freezes. One run carries all the answers, and it starts when every call of the turn has one.
- Reject answers its call at once. Invalidation does not start a run: `invalidated` goes with the user's next message.
- **Stop does not close the connection.** Closing does not stop ADK: the model keeps generating, the answer lands in the server's session, and a run sent right after mixes up the history. Stop hides the rest of the text and reads the run to `RUN_FINISHED` or `RUN_ERROR`. The connection closes only with the screen.
- After Stop, the text already shown stays, marked "Stopped", and only that text goes back in the history. None of its remaining calls runs. Until the run ends the chat shows "Stopping…" and a new message waits.
- Before each new user message, every call without an answer is answered, all in one run, the message last. Executed: the real result. Not executed (Stop, or the user wrote instead of deciding): `cancelled`. Invalidated: `invalidated`. The status goes in `content`, because the middleware ignores `error` and the model reads an empty `content` as success. AG-UI 1.0 also wants every call answered before the thread goes on.
- A run is never sent twice: the server would answer with an empty `RUN_STARTED`/`RUN_FINISHED` pair.
- A run that breaks without a final event shows "Connection lost" and the next message starts a new thread with fresh history.
- No bytes for 60 s counts as a broken run. ADK pings every 15 s, but the parser drops comments, so the timeout watches the raw bytes.
- `threadId` lives as long as `TandemScope` and never comes back after the screen closes: an orphaned ADK run would mix up the history.
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

## Tool answers

The `content` of the tool message. The constants are in `session.dart`.

| Situation | Content |
|---|---|
| executed | `jsonEncode(result)`, `null` for `void` |
| refused: not listed now, needs approval, bad arguments | `{"status":"refused","reason":<message>}` |
| the method threw | `{"status":"failed","error":<toString>}` |
| Reject | `{"status":"rejected_by_user"}` |
| not executed, or the user wrote instead of deciding | `{"status":"cancelled"}` |
| invalidated | `{"status":"invalidated"}` |

A bare `rejected` is out: Gemini read it as a refusal of the system. `rejected_by_user` is provisional: it is not yet checked against a real model.

## Deferred

- Riverpod.
- AG-UI interrupts.
- Resync of a broken run through the experimental `/agents/state`.
- A loop guard, if a real model loops.
- l10n: the UI strings are English constants.
- `additionalProperties: false` in the schemas, after Gemini accepts it.
- The order-desk demo and `example/agent`, which the README links.
- Publishing: `publish.yml` is unchanged and still publishes the repo root, which is no longer a package. Three packages need a release each, `tandem` first.
