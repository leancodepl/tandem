---
name: tandem-in-app-agent
description: Give an agent-aware Flutter screen an in-app agent for the app's users, with a chat or a button, over an AG-UI backend or Apple's on-device model. Use when asked to add an AI chat, assistant or "fill with AI" button to a screen that has a TandemScope, or when the code uses TandemSessionScope, ScriptedAgent or OnDeviceAgent.
user-invocable: false
---

# Add an in-app agent to a Tandem screen

The in-app agent works with the app's users: they write to it, it calls the methods the screen lists, and they approve what matters. The screen needs a `TandemScope` around a state class with `@TandemAgent()`; if it has none, follow `tandem-agent-aware-screen` first. The steps use the order screen of that skill. Do them in order and check each "Done when" before the next.

## 1. Choose with the user

Ask the user two questions, unless the request already answers them:

- **How the user talks to the agent.** A chat next to the screen, or a button that sends one prepared message, such as "Fill from e-mail" next to a pasted text. A button needs no chat.
- **Which agent.**
  - An AG-UI backend: the user gives its address. Any AG-UI endpoint works. Tandem is checked with Google ADK, LangGraph and Pydantic AI, and [`example/agents`](https://github.com/leancodepl/tandem/tree/main/example/agents) has an agent on each to copy from.
  - Apple's on-device model, on iOS and macOS 26 with Apple Intelligence: no backend and no API key. It is experimental and small: offer it only for the simplest tasks, such as one sentence that becomes one call.

**Done when** you know both answers, and the backend's address when there is one. Without an address, put none into the app: step 7 tests the screen with a script, and the address comes later.

## 2. Connect the agent

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
- The backend must put the AG-UI `context` into the model's prompt (ag-ui-adk, ag-ui-langgraph and Pydantic AI do not on their own; the agents in `example/agents` show how) and accept `tools` on every run. On the web it needs CORS for the app's origin. A sandboxed macOS app needs the `com.apple.security.network.client` entitlement in both entitlement files.
- For a backend that needs the user's token, pass `HttpAgentConnection(uri, client: ...)` with an `http.Client` that adds it to `TandemScope.connected`, and keep the connection in a field.

For Apple's on-device model, pass `OnDeviceAgent.apple()` to `TandemScope.connected` as `connection`; calling it in `build` is fine. Offer it only when `await OnDeviceAgent.apple().availability()` is `available`. On `RunFailed(code: OnDeviceErrorCode.contextWindowExceeded)`, call `session.startOver()`. [Requirements and limits](https://github.com/leancodepl/tandem#apples-on-device-model).

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
- `session.startOver()` sends the next message to a new thread without the earlier history, such as after a `RunFailed` whose `code` says the history no longer fits. It does nothing while a run is open. Give the `startedOver` notice a line too.
- [`example/lib/agent_chat.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the Tandem repository does all of this in one file. Copy its structure, not its texts.

**Done when** the switches over `ChatItem` and `session.status` have no `_` case, or the button disables itself while the status is not `Idle`.

## 4. Approve in the chat

A screen with `.callsWithApproval` asks the user in one place. With a chat, that is a card in it, and the scope has `approvals: const .fromState()`. With a button, keep the dialog of `tandem-agent-aware-screen`, `approvals: .callback(...)`. Requests of a coding agent show in the same place.

- A card whose `request.status` is `pending` has Approve and Reject, which call `session.approve(request)` and `session.reject(request)`. Both throw an `ApprovalNotPending` when the request changed as the user tapped, such as when what the agent sees changed: catch it, the card then shows the new `request.status`.
- Every other `request.status` gets a line: `approved`, `rejected`, `invalidated` (what the screen shows changed after the call asked) and `cancelled`. Its line names whom to ask again, by `request.caller`.
- `request.description` and `request.arguments` are written for the agent. Show the user what the method will do in the app's words, chosen by `request.tool`.

**Done when** every `.callsWithApproval` method shows to the user before it runs, as a card or in the dialog.

## 5. Show the status

When the screen has no chat, show what the agent does now, such as a progress line, by switching on `session.status`: `Idle`, `Thinking` (with the `backendTool` that runs now, if any), `Calling(:tool)`, `AwaitingApproval(:request)` and `Stopping`. A chat shows it in its button. When the backend keeps a state of its own, such as the steps of its plan, `session.agentState` has it as it streams: read the keys that backend writes.

**Done when** the user sees that the agent works, and when it waits for them.

## 6. Let the agent draw, if the user wants it

Only with an AG-UI backend and a strong remote model, such as Gemini: a small local model or Apple's on-device model rarely writes valid A2UI. Put `const TandemView()` below the scope where the drawn view goes, in a scroll view when it can be taller than its space. Every run then offers the agent the tool `tandem_show_view`, which teaches it seven components, without form fields. The view shows only what `.sees` lists, and a view that does not fit the screen is refused with what to fix. While the agent draws, the status is `Thinking(drawing: true)`. A button calls a listed method with the usual approvals, as `caller: Caller.view`; give the card of such a request its own text, since the user pressed it. The agent reads what a press answered in `app_notes` on its next run; to let it react at once, call `session.wake()` in `onEvent`.

**Done when** `TandemView` is below the scope, or the user wants no drawn view.

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

The same script in place of the backend runs the screen in the app, without a backend, such as with `flutter run -t lib/try_it.dart`.

**Done when** the test passes and shows the state the method changed.

## Mistakes

- A chat with no `TandemScope` above it.
- An address in the app that no backend answers, such as a placeholder. Every message fails.
- `approvals: .none()` on a screen with `.callsWithApproval`. Every such call is refused.
- A connection or a `ScriptedAgent` made in `build`. A new connection starts a new session, so keep it in a field. `OnDeviceAgent.apple()` returns the same one every time.
