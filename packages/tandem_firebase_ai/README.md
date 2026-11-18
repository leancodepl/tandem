# tandem_firebase_ai

Connect Firebase AI Logic to your Flutter app's screens and actions with
[Tandem](https://tandem.leancode.co). No custom agent backend is required.

The model reads the screen's current state and proposes calls to the methods it
exposes. Tandem checks arguments, executes methods and asks for approval where
the screen declares `.callsWithApproval`.

## Connect a screen

Use `tandem_firebase_ai` 0.1.0 with `tandem` 0.3.3 or a compatible later
0.3.x release. The connection uses message metadata introduced in 0.3.3 to
continue a conversation after a tool call.

Set up [Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter)
and [App Check](https://firebase.google.com/docs/ai-logic/app-check) in your app.
Initialize Firebase and activate App Check before the first model request.

Create a connection once, outside `build`:

<!-- example/lib/main_firebase.dart -->
```dart
  final connection = FirebaseConnection(
    firebase: FirebaseAI.googleAI(),
    model: model,
    instructions:
        'Help the user prepare their order. '
        'Describe the result after each change. '
        'Only place an order when the user asks you to.',
  );
```

Import `package:firebase_ai/firebase_ai.dart` and
`package:tandem_firebase_ai/tandem_firebase_ai.dart`. `model` is the name of a
Gemini model available in your project that supports function calling.

Pass the connection to your existing scope:

<!-- example/lib/firebase_order_app.dart -->
```dart
      child: TandemScope.connected(
        surface: (context) => context.read<OrderCubit>(),
        connection: connection,
        approvals: const .fromState(),
```

The screen and chat go in the scope's `child`, as with any other Tandem
connection. Keep the same connection while its threads are in use. Several
screens may share a connection; their conversations stay separate. A connection
owns only its active requests, so it needs no `dispose` call from the app.

The [runnable example](https://github.com/leancodepl/tandem/blob/main/example/README.md#connect-directly-to-firebase-ai-logic)
includes Firebase configuration, a form, streaming chat, approvals and Stop.
Its `Orders` implementation stores orders in memory.

## What the adapter handles

- Text input, streamed text output and multi-turn conversation.
- Current `.sees`, `.calls` and `.callsWithApproval` on each model request.
- Several proposed calls in one answer, with the actual results returned by
  Tandem. The adapter waits for the complete answer and checks all tool names
  and native call IDs before handing any calls to Tandem. Tandem checks each
  method's arguments when it handles that call.
- Existing `TandemView` catalogs through the `tandem_show_view` tool.
- Gemini's native response parts and thought signatures in message metadata.
- Stop, request timeout and cleanup when the session leaves the screen.

Tandem owns the conversation and tool execution. Use its `TandemThread`,
`session.send`, `session.stop` and approval methods. The adapter adds no separate
chat session or tool registry. `instructions` supplies system guidance.
Each request includes the current screen context in a separate text part of
the latest user turn. Earlier turns omit these snapshots.

## Configuration

`FirebaseConnection` requires `firebase` and `model`. It also accepts:

| Parameter | Meaning |
|---|---|
| `instructions` | Application instructions, empty by default |
| `generationConfig` | Firebase's `GenerationConfig`, including output token and thinking settings |
| `safetySettings` | Firebase's `SafetySetting` list |
| `idleTimeout` | Maximum wait for credentials, response headers or the next response bytes. Defaults to 60 seconds. SSE heartbeats count as bytes even while the model is silent. |

With `FirebaseAI.googleAI()`, leave `SafetySetting.method` null: the SDK
refuses the setting, and the run fails with `FirebaseErrorCode.invalidInput`.

One candidate and text output are supported. Requests for multiple candidates,
image generation or speech generation are rejected. Model-specific combinations
of structured output and function calling remain subject to Firebase's model
support. Files, images, audio, Live API and grounding are outside this adapter's
scope.

Project selection, App Check, Firebase Authentication and quotas stay in the
application's Firebase configuration. Approval cards govern the app's user
experience; authorization for protected data still belongs to the service that
stores it.

## Stop and errors

Stop prevents the remaining methods from running and aborts the client request.
It cannot undo a method that already ran or guarantee that generation stopped
on Firebase's servers. Closing the screen cancels that request without closing
other screens' requests.

Failures appear through Tandem's `RunFailed` event. `FirebaseErrorCode`
distinguishes invalid input or responses, incompatible history, blocked output,
output limits, timeouts and other generation failures. A blocked chunk ends the
run before its text is shown. Earlier streamed text can remain visible. The app
receives tool calls only after the entire response completes successfully.
The adapter does not retry requests or shorten history automatically.

Keep a thread with the connection that created its native history. Start a new
thread when replacing the connection or model. Signed tool history that no
longer matches the retained conversation fails explicitly instead of replaying
different arguments or text. Visible partial text without retained tool calls
can continue as ordinary text.

If you press Stop after Gemini finishes an answer with tool calls but before
all its text appears, the visible text can differ from the signed answer.
The next send reports `FirebaseErrorCode.incompatibleHistory`. Start a new
thread to continue.
