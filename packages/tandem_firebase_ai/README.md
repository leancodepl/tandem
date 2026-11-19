# tandem_firebase_ai

Connect Firebase AI Logic to the screens of your Flutter app with
[Tandem](https://tandem.leancode.co). The app needs no agent backend.

Gemini reads what a screen lists with `.sees` and proposes calls of the
methods the screen lists with `.calls` and `.callsWithApproval`. Tandem checks
the arguments, runs the methods in the app and asks the user to approve the
calls that need approval.

## Connect a screen

`tandem_firebase_ai` 0.1.0 needs `tandem` 0.3.3 or a later 0.3.x release.

Set up [Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter)
and [App Check](https://firebase.google.com/docs/ai-logic/app-check) in your app.
Initialize Firebase and activate App Check before the first message.

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
Gemini model in your project that supports function calling.

Pass the connection to your scope:

<!-- example/lib/firebase_order_app.dart -->
```dart
      child: TandemScope.connected(
        surface: (context) => context.read<OrderCubit>(),
        connection: connection,
        approvals: const .fromState(),
```

The screen and the chat go in the scope's `child`, as with any other Tandem
connection. Several screens can share one connection, and each keeps its own
conversation. The connection needs no `dispose` call.

The [runnable example](https://github.com/leancodepl/tandem/blob/main/example/README.md#connect-directly-to-firebase-ai-logic)
has the Firebase configuration, a form, a chat, approvals and Stop. Its
`Orders` class keeps the orders in memory.

## What a run does

- A run sends the screen's current `.sees`, `.calls` and `.callsWithApproval`
  and asks Firebase for one answer. The `.sees` values go as data in the
  latest user turn. `instructions` go in the system instruction.
- Text reaches the chat while Firebase streams it.
- Tool calls reach Tandem only after Firebase sent the whole answer with the
  finish reason `STOP`. One call of a tool the run does not offer fails the
  run, and Tandem gets none of the answer's calls.
- A `TandemView` catalog works through the `tandem_show_view` tool.
- Gemini needs its answer back with the thought signatures of its parts. The
  connection keeps the answer in the metadata of the assistant message, so
  the answer stays in the `TandemThread`.

The connection has no chat session and no tool registry of its own. Use
`TandemThread`, `session.send`, `session.stop` and the approval methods.

## Settings

`generationConfig` and `safetySettings` take Firebase's own types. The
connection delivers one candidate of text. Its constructor throws an
`ArgumentError` for several candidates, image output or speech output. Files,
images, audio, the Live API and grounding are not supported.

`idleTimeout` is 120 seconds by default. It limits three waits: for
credentials, for the response headers and for the next bytes of the response.
A model that thinks for longer without sending bytes fails the run with
`FirebaseErrorCode.timedOut`.

The connection is tested on a real model with `FirebaseAI.googleAI()`, the
Gemini Developer API, and not with `FirebaseAI.agentPlatform()`. With the
Gemini Developer API, leave `SafetySetting.method` null: the SDK refuses the
setting, and the run fails with `FirebaseErrorCode.invalidInput`.

Project selection, App Check, Firebase Authentication and quotas belong to
the app's Firebase configuration. An approval card is not authorization: the
service that stores protected data still decides who may change it.

## Stop and errors

Stop ends the run in the app and aborts its HTTP request. Tandem runs none of
the run's remaining calls, and the next run sends the text the user saw. Stop
does not undo a method that already ran, and Firebase may go on generating and
charge for it. A screen that closes cancels only its own request.

A failed run reaches the app as Tandem's `RunFailed` event with a
`FirebaseErrorCode`. A blocked chunk ends the run before its text shows, but
text of earlier chunks stays in the chat. The connection does not retry a
request and does not shorten the history.

`FirebaseErrorCode.incompatibleHistory` means that the thread has tool calls
or messages this connection cannot send to Firebase. Start a new thread then.
The known causes:

- Another connection wrote the thread: a second `FirebaseConnection`, or one
  to an AG-UI backend. Keep a thread with the connection that started it,
  also when you change the model.
- Firebase refused the thought signatures of the thread.
- A wrapper around the connection delivered a finished answer late, and the
  user pressed Stop before all its text showed. Pass the `FirebaseConnection`
  itself to the scope to rule this case out.
