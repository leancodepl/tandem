# RFC 0002: an on-device Apple connection

Status: draft, example-only pilot. Date: 2026-10-19.

## Goal

Let an app try Tandem with Apple's on-device model before building an AI backend. The app still
owns its state, callable methods and approvals. Foundation Models supplies inference inside the
app. This does not expose the app to Siri through App Intents.

The pilot stays in `example`. It introduces no public package API and keeps the scripted gallery
as the default. Run it with the [example instructions](../../example/README.md#apple-on-device-ai-pilot).

## Current boundary

`AppleModelConnection` implements the existing `AgentConnection` interface. It sends each AG-UI
run input over a Flutter method channel and maps a native text reply or one selected tool call
back to AG-UI events. The same `TandemScope` executes methods and handles approvals.

The native runner builds a fresh Foundation Models session from the current tools, screen
context and conversation. `AppleToolSchema` translates a bounded JSON Schema subset into
`DynamicGenerationSchema`: objects with explicit properties, strings and string enums, booleans,
integers, numbers and arrays. Unsupported keywords, nullable unions, references and open
dictionaries fail explicitly. This is sufficient for the shopping list, not every Tandem screen.

`AppleHandoffTool.call` records a request and throws an internal handoff error. It never runs a
screen method. This is an experimental bridge around Foundation Models' native tool execution:
Tandem receives the selection after the native response ends, checks the current capabilities
and handles approval before execution. Cancellation reaches the native task and late responses
are discarded by Dart.

The next run contains Tandem's actual tool result. The adapter acknowledges it without another
generation and ends the turn. Rejection, invalidation, cancellation and refusal do not claim
success. A failed method may have effects; an unreadable result must not trigger a retry.
The acknowledgment does not summarize returned application data.

## Limits of this pilot

- One selected action per user message. Ask for actions separately. A compound prompt has no
  guarantee of selecting its first action: native tool callbacks may run concurrently.
- A model selection is not proof of user intent. Local experiments included wrong mutations,
  skipped conditions and inaccurate text. The app's real state is authoritative.
- The OS supplies the local model. A supported device, enabled Apple Intelligence and downloaded
  model are required. There is no cloud fallback or bundled replacement model.
- The runtime was exercised on macOS. The iOS host builds, but physical iPhone generation remains
  unverified. A simulator reported availability while generation failed. Do not infer simulator
  support from that availability check.
- Flutter tests fake native responses. The standalone native `--check` covers history and result
  handling; it does not establish model quality or general schema compatibility.

## Why multi-step execution is separate

In a local native-tool experiment, the model declared quantity edits before checkout, but the
checkout callback arrived before the edits. An actor protected the fake state from races; it did
not preserve the intended action order. Throwing the handoff error also did not leave a complete
ordered call batch in the session transcript. Direct callback execution is therefore not the
foundation for sequential Tandem operations.

A separate guided-generation experiment produced an ordered plan using a closed union of
operation-specific argument types. Three synthetic cases yielded valid plans that a fake
executor could validate and execute serially, stopping at denied approval. A loose structure
with a name and optional arguments also produced irrelevant fields and rejected plans. These
small probes show feasibility, not reliability. They did not test a real Tandem plan executor,
approval followed by resume, or planning from a result that was unknown in advance.

Before extending the pilot, evaluate a typed plan that is data rather than executable callbacks.
Validate the whole plan, execute one step through Tandem, and recheck capabilities, state and
approval before the next step. Define what rejection, stale state, cancellation and partial
failure do before allowing automatic continuation. Keep returned state and results distinct
from model-written success text.

## Review questions

1. Is the example-only `AgentConnection` seam enough to evaluate local inference?
2. Should a future Apple package use native tools, guided plans, or separate modes for each?
3. Which schema subset and device/language matrix must be supported before package extraction?

## Apple references

- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Expanding generation with tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling)
- [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
