---
name: tandem-in-app-agent
description: Give an agent-aware Flutter screen an in-app agent for the app's users, with a chat or a button, using Firebase AI Logic or an AG-UI backend. Use when asked to add an AI chat, assistant or "fill with AI" button to a screen that has a TandemScope, or when the code uses TandemSessionScope, ScriptedAgent, FirebaseConnection or OnDeviceAgent.
user-invocable: false
---

# Add an in-app agent to a Tandem screen

The in-app agent works with the app's users: they write to it, it calls the methods the screen lists, and they approve what matters. The screen needs a `TandemScope` around a state class with `@TandemAgent()`; if it has none, follow `tandem-agent-aware-screen` first. The steps use the order screen of that skill. Do them in order and check each "Done when" before the next.

## 1. Choose with the user

Ask the user two questions, unless the request already answers them:

- **How the user talks to the agent.** A chat next to the screen, or a button that sends one prepared message, such as "Fill from e-mail" next to a pasted text. A button needs no chat.
- **How to connect the model.** Use `tandem_firebase_ai` for Firebase AI Logic without a custom agent backend, or use an AG-UI backend whose address the user supplies. Tandem is checked with Google ADK, LangGraph and Pydantic AI, and [`example/agents`](https://github.com/leancodepl/tandem/tree/main/example/agents) has an agent on each to copy from.

**Done when** you know both answers, and the backend's address when there is one. When the chosen connection is not configured yet, step 7 tests the screen with a script until it is ready.

## 2. Connect the agent

For Firebase AI Logic, add `tandem_firebase_ai` and `firebase_ai`. Read the adapter README of the installed version for its Firebase and App Check setup and supported settings. Create one `FirebaseConnection(firebase: ..., model: ..., instructions: ...)` outside `build` and pass it as `connection:` to `TandemScope.connected`. Keep the screen's existing `surface`, `approvals` and `onEvent`. Tandem supplies tools and keeps history; the app configures Firebase. Start a new `TandemThread` before replacing the connection or model.

For a backend, give the scope its address:

```dart
TandemScope(
  surface: (context) => context.read<OrderCubit>(),
  agent: Uri.parse(agentUrl),
  approvals: const .fromState(),
  onEvent: showOrderMessages,
  child: const Row(
    children: [
      Expanded(child: OrderForm()),
      SizedBox(width: 360, child: AgentChat()),
    ],
  ),
)
```

- Read the address from the app's configuration, as the app reads its other servers.
- The backend must put the AG-UI `context` into the model's prompt (ag-ui-adk, ag-ui-langgraph and Pydantic AI do not on their own; the agents in `example/agents` show how) and accept `tools` on every run. Its `RUN_STARTED` must repeat the input's `threadId` and `runId`, as these three adapters do. On the web it needs CORS for the app's origin. A sandboxed macOS app needs the `com.apple.security.network.client` entitlement in both entitlement files.
- For a backend that needs the user's token, pass `HttpAgentConnection(uri, client: ...)` with an `http.Client` that adds it to `TandemScope.connected`, and keep the connection in a field.
- For another transport, implement an `AgentConnection` whose `run` passes `agUiRun(input)` only the decoded frames of that run's request, with an `input` that carries the IDs the server will echo. Follow the [transport rules](https://github.com/leancodepl/tandem#the-agent-backend) for routing, timeouts and cancellation. A transport with a cancel message also implements `StoppableAgentConnection`, whose `stop(input)` gets the same input object as `run`. Pass the connection to `TandemScope.connected` and keep it in a field.

`OnDeviceAgent` is deprecated and goes away in 0.4.0. Where the app uses it, connect the screen through Firebase AI Logic or an AG-UI backend instead.

For a screen that opens again, such as a page the user leaves and comes back to, keep a `TandemThread` above it and pass it as `thread:`, so the chat and the agent's history go on. One screen at a time has it. When the backend keeps the conversation under its own ID, pass it: `TandemThread(id: ThreadId(conversationId))`, kept in a field or a `State` like any thread, not built in `build`. Tandem then never changes the ID. [What the backend must do](https://github.com/leancodepl/tandem#the-agent-backend).

`onEvent: (context, event, session) { ... }` hears what happens in the session: an `AgentCall` for every listed method that returned (`tool`, `arguments`, `result` and `caller`, who called it), `RunStopped`, `RunFailed` and `ConnectionLost`. Without a chat, show `RunFailed` and `ConnectionLost` to the user, such as in a snackbar. To tell the agent what happened outside the chat, call `session.note(text)`; `session.wake()` lets it take a turn on it.

**Done when** the scope has `agent:`, or `TandemScope.connected` with the connection, and the app builds.

## 3. Build the chat or the button

Tandem has no chat widget. `TandemSessionScope.of(context)` gives the session and rebuilds the widget when it changes. Write the texts as the rest of the app does: from its localization when it has one, inline when it has none.

A button calls `session.send` with its message, such as the pasted text, and shows `session.status` while the agent works. It shows the agent's last `AgentMessage` from `session.items`.

A chat:

```dart
final class const AgentChat() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    // The items of session.items, then the field and its button.
  }
}
```

- Show every item of `session.items`, oldest first, with a `switch` over `ChatItem`: `UserMessage` and `AgentMessage` by their `text`, except a `UserMessage` with `fromApp`, which `session.wake` sent for the agent, an `AgentMessage` with `stopped` marked as stopped, a `ChatNotice` by its `kind`, an `ApprovalRequest` as a card.
- The field calls `session.send(text)`. Its button switches on the sealed `session.status`: Send for `Idle()` and `AwaitingApproval()`, Stop that calls `session.stop()` for `Thinking()` and `Calling(approved: false)`, a disabled Stop for `Calling(approved: true)` (an approved method runs to its end) and a disabled "Stopping" for `Stopping()`.
- `session.startOver()` clears the local history and agent state, such as after a `RunFailed` whose `code` says the history no longer fits. If the app gave the thread its ID, the next run keeps it and sends the completed calls and their unsent answers first. The backend may keep its history. Use a new `TandemThread` with a new backend ID for a separate conversation. An app that gives the thread its ID words the `connectionLost` and `startedOver` notices for a backend that keeps the conversation, without saying that a new one starts.
- [`example/lib/agent_chat.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the Tandem repository does all of this in one file. Copy its structure, not its texts.

**Done when** the switches over `ChatItem` and `session.status` have no `_` case, or the button disables itself while the status is not `Idle`.

## 4. Approve in the chat

A screen with `.callsWithApproval` asks the user in one place. With a chat, that is a card in it, and the scope has `approvals: const .fromState()`. With a button, keep the dialog of `tandem-agent-aware-screen`, `approvals: .callback(...)`. Requests of a coding agent show in the same place.

- Use `request.key` for the card's widget key and for any data you capture when it shows. The `ApprovalKey` stays the same when the status changes. A new request gets its own key.
- A card whose `request.status` is `pending` has Approve and Reject, which call `session.approve(request)` and `session.reject(request)`. Both throw an `ApprovalNotPending` when the request changed as the user tapped, such as when what the agent sees changed: catch it, the card then shows the new `request.status`.
- Every other `request.status` gets a line: `approved`, `rejected`, `invalidated` (what the screen shows changed after the call asked) and `cancelled`. Its line names whom to ask again, by `request.caller`.
- `request.description` and `request.arguments` are written for the agent. Show the user what the method will do in the app's words, chosen by `request.tool`.

**Done when** every `.callsWithApproval` method shows to the user before it runs, as a card or in the dialog.

## 5. Show the status

When the screen has no chat, show what the agent does now, such as a progress line, by switching on `session.status`: `Idle`, `Thinking` (with the `backendTool` that runs now, if any), `Calling(:tool)`, `AwaitingApproval(:request)` and `Stopping`. A chat shows it in its button. When the backend keeps a state of its own, such as the steps of its plan, `session.agentState` has it as it streams: read the keys that backend writes.

**Done when** the user sees that the agent works, and when it waits for them.

## 6. Let the agent draw, if the user wants it

Use Firebase AI Logic or an AG-UI backend with a strong remote model, such as Gemini: a small local model rarely writes a valid view. List the app's widgets the agent may draw with in a class with `@TandemCatalog([...])`, `final class const AppCatalog() with _$AppCatalog;`, give each widget a doc comment, and give the class a doc comment with guidelines and one example view in a ```json block. The guidelines and the example name one screen's data and methods, so another screen that draws with the same widgets gets its own catalog class from the same list, as `@TandemCatalog([...DesignSystem.components])`. A design system can export its widgets as a `static const` list that the app spreads. A required parameter of a type without a form, such as `IconData`, stops the build: add a `JsonConverter<IconData, String>` to `converters:`. Run build_runner. Then put `TandemView(catalog: const AppCatalog())` below the scope where the view goes, in a scroll view when it can be taller than its place. Every run then offers the agent `tandem_show_view`. A view is checked before it shows, and a view that does not fit is refused with what to fix; after three refusals in a row the agent answers in text until the next message. While the agent draws, the status is `Thinking(drawing: true)`. An action calls a listed method with the usual approvals, as `caller: Caller.view`; give the card of such a request its own text, since the user pressed it. The agent reads what an action answered in `app_notes` on its next run; to let it react at once, call `session.wake()` in `onEvent`.

**Done when** `TandemView` with the app's catalog is below the scope and the build passes, or the user wants no drawn view.

## 7. Test it with a script

`ScriptedAgent` plays a script instead of a model, so the test needs no network and no key:

```dart
import 'package:tandem/testing.dart';

testWidgets('the agent sets a quantity from the chat', (tester) async {
  final cubit = OrderCubit(orders: Orders());
  final agent = ScriptedAgent([
    (_) => const [
      AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 15}),
    ],
    (_) => const [AgentStep.say('Done.')],
  ]);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: TandemScope.connected(
          surface: (context) => context.read<OrderCubit>(),
          connection: agent,
          approvals: const .fromState(),
          child: const AgentChat(),
        ),
      ),
    ),
  );

  await tester.enterText(find.byType(TextField), 'fifteen monitors');
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();

  expect(cubit.draft.lines.single.quantity, 15);
  expect(find.text('Done.'), findsOneWidget);
});
```

Every turn of the script is one run: the first calls the tool, the second comes after Tandem sent the answer. `agent.requests` holds every body sent, so a test can check what the agent saw in `context`. `find.text('Send')` stands for the chat's send button. To approve a call, tap the card's Approve. Keep a `ScriptedAgent` in a field or a test variable, never in `build`: a new connection starts a new session.

The finite script ends with `RUN_ERROR` after its last turn, and so does a `callTool` of a tool the run does not offer. For a fixed demo that handles every run with the same callback, use `ScriptedAgent.repeating(turn)`. Inside the callback, `AgentRequest(raw)` reads the user's latest text, named context, offered tools, trailing tool answers matched by call ID, new app notes and the actions the user pressed in a drawn view. Compare a `status` with `ToolStatus`, and draw with `AgentStep.showView`. Keep the app's decisions and wording in its script. Use raw `agent.requests` for wire assertions. [Testing API](https://github.com/leancodepl/tandem#testing).

The same script in place of the backend runs the screen in the app, without a backend, such as with `flutter run -t lib/try_it.dart`.

**Done when** the test passes and shows the state the method changed.

## Mistakes

- A chat with no `TandemScope` above it.
- An address in the app that no backend answers, such as a placeholder. Every message fails.
- `approvals: .none()` on a screen with `.callsWithApproval`. Every such call is refused.
- A connection or a `ScriptedAgent` made in `build`. A new connection starts a new session, so keep it in a field.
