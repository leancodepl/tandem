<p align="center">
  <img src="https://github.com/leancodepl/tandem/raw/main/doc/imgs/logo.svg" alt="tandem: a pixel-art tandem bike, the agent pedalling behind and the user steering in front" width="400">
</p>

<br>

# tandem

<p>
  <a href="https://pub.dev/packages/tandem"><img src="https://img.shields.io/pub/v/tandem?style=for-the-badge&logo=dart" alt="tandem on pub.dev"></a>
  <a href="https://github.com/leancodepl/tandem/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/leancodepl/tandem/test.yml?branch=main&style=for-the-badge&logo=github" alt="Test status"></a>
  <a href="https://github.com/leancodepl/tandem/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-green?style=for-the-badge" alt="License: Apache 2.0"></a>
  <a href="https://pub.dev/packages/leancode_lint"><img src="https://img.shields.io/badge/style-leancode__lint-f0ff00?style=for-the-badge" alt="style: leancode_lint"></a>
</p>

**Make your Flutter app intelligent, one feature at a time.**

Start with your coding agent. In 10 minutes, it fills a form in your running app through the setters your buttons already call. No backend or API key is needed. Give Claude Code this prompt in your app's folder:

```text
Run `dart run skills@ add leancodepl/tandem --skill tandem --agent claude`, then read `.claude/skills/tandem/SKILL.md` and follow it.
```

In a new session, `/tandem` starts the same workflow. Claude Code is the only coding agent Tandem is tested with. You can set up Cursor with `--agent cursor` and `.cursor/skills/tandem/SKILL.md`, or Codex with `--agent codex` and `.agents/skills/tandem/SKILL.md`. These setups have not been tested.

Pick a screen. Its state class lists the data an AI agent can read and the methods it can call. Those methods use the same validation as your buttons. Calls marked for approval wait for the user. Add a `TandemView` for the agent to draw a view, such as an order summary with a button to place the order. The integration stays within that screen.

## How it works

![The Flutter app with tandem sends the agent backend the user's message, what the agent sees and what it may call, over AG-UI. The backend keeps the API key, asks the model, and sends back replies, calls to the app's methods and views in A2UI, which TandemView draws. On iOS and macOS 26, OnDeviceAgent does the same with Apple's on-device model, without a backend or an API key.](https://github.com/leancodepl/tandem/raw/main/doc/imgs/how-it-works.svg)

With a remote agent, your backend calls the model and keeps the API key. The app talks to the backend over [AG-UI](https://docs.ag-ui.com), an open protocol between agents and apps. Tandem is checked with Google ADK, LangGraph and Pydantic AI. Other AG-UI backends can connect by following [the backend contract](#the-agent-backend).

On iOS and macOS 26, the experimental `OnDeviceAgent` can run [Apple's on-device model](#apples-on-device-model) instead, without a backend or an API key, for the simplest tasks. The screen, its capabilities and approvals stay the same.

In a debug build, [your coding agent](#your-coding-agent), such as Claude Code, calls the same methods through `TandemBridge`, with the same checks and approvals.

The in-app agent sends [A2UI](https://a2ui.org) views through the `tandem_show_view` tool. [`TandemView`](#views-the-agent-draws) renders them in your app. A view can bind to the screen's data, and its buttons call the screen's listed methods.

Your state class lists what the agent may do:

<!-- example/lib/order_cubit.dart -->
```dart
  List<AgentCapability> get agentCapabilities => [
    .sees(draft),
    .calls(setQuantity),
    if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
  ];
```

- `.sees(draft)`: the agent reads the current draft at the start of each run. Other state values are not sent unless the class lists them.
- `.calls(setQuantity)`: the agent calls the same method as a button. The same validation runs, and the screen updates as it would after a tap.
- `.callsWithApproval(placeOrder)`: the method runs only after the user approves the call.

> [!NOTE]
> Tandem is experimental. Its API can change before 1.0.

## Quick start

Requires Dart 3.13 (Flutter 3.47) or newer.

1. Add the packages. Keep both on the same minor version: the generated code follows the API of `tandem`.

   ```sh
   flutter pub add tandem
   flutter pub add dev:build_runner dev:tandem_generator
   ```

2. List what the agent may see and call:

   <!-- example/lib/order_cubit.dart -->
   ```dart
   part 'order_cubit.g.dart';

   @TandemAgent()
   class OrderCubit({required final Orders orders})
       extends Cubit<OrderState>
       with _$OrderCubit {
     this : super(.new(draft: .empty));

     @override
     List<AgentCapability> get agentCapabilities => [
       .sees(draft),
       .calls(setQuantity),
       if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
     ];

     @override
     Stream<Object?> get changes => stream;

     /// The order as the user sees it on the screen.
     OrderDraft get draft => state.draft;

     /// Sets how many pieces of [sku] the order has.
     void setQuantity(String sku, int quantity) =>
         emit(.new(draft: draft.withQuantity(sku, quantity)));

     /// Places the order exactly as it is on the screen.
     Future<OrderId> placeOrder() => orders.place(draft);
   }
   ```

   Doc comments describe the listed data and methods. Parameter types define the tools' schemas. Tandem reads the list before each run, so available methods can depend on the state or the current user. The `changes` stream reports every state change. Here it is the Cubit's `stream`. For provider and Riverpod, see [Any state library](#any-state-library).

3. Generate the code:

   ```sh
   dart run build_runner build
   ```

   Every class with `@TandemAgent()` gets a `_$Name` mixin. Each `.sees` entry must appear directly in the list. Putting it inside an `if`, a `for`, a `?:` or a spread fails the build. An outdated `.g.dart` is not always caught at runtime, so check the generated code in CI:

   ```sh
   dart run build_runner build && git diff --exit-code
   ```

4. Wrap the screen:

   <!-- example/lib/order_screen.dart -->
   ```dart
   final class const OrderScreen({super.key}) extends StatelessWidget {
     @override
     Widget build(BuildContext context) => BlocProvider(
       create: (context) => OrderCubit(orders: context.read<Orders>()),
       child: TandemScope(
         surface: (context) => context.read<OrderCubit>(),
         approvals: const .callback(confirmOrder),
         child: const Scaffold(body: OrderForm()),
       ),
     );
   }
   ```

   The scope reads the Cubit through `surface` when the session opens. `confirmOrder` shows a dialog to approve or reject `placeOrder` ([Approvals](#approvals)). This scope is ready for a coding agent. To connect an AG-UI backend, see [An in-app agent](#an-in-app-agent).

5. Enable the debug bridge in your app's `main()`. The example enables it before starting the order desk:

   <!-- example/lib/main.dart -->
   ```dart
   void main() {
     TandemBridge.enable();
     runApp(const OrderDeskApp());
   }
   ```

   Run your app in debug and ask your coding agent to fill the wrapped screen, for example from an e-mail. [Your coding agent](#your-coding-agent) explains how the agent reaches the app.

> [!TIP]
> `/tandem` from the prompt above walks your coding agent through these steps. `dart run skills@ get --package tandem --all` installs the skills of your version of Tandem: the base steps, the coding agent and the in-app agent.

## Try it without a key

### Run the order desk

The [example](https://github.com/leancodepl/tandem/blob/main/example/README.md) runs an order desk on Android, iOS and macOS with scripted responses. It needs no backend or API key. The script fills an order, draws a summary and asks before placing it. It follows a fixed scenario rather than interpreting arbitrary messages.

The app enables `TandemBridge`, so your coding agent can fill the order too. Its [scripted agent](https://github.com/leancodepl/tandem/blob/main/example/lib/desk/order_desk_agent.dart) uses `ScriptedAgent.repeating` to handle every run with the same callback. The reference backends can also return scripted responses for testing their AG-UI integration without a model.

### Apple's on-device model

> [!WARNING]
> Experimental. Use Apple's model for simple tasks, such as turning a sentence into one method call. This connection is outside Tandem's release checks.

The invoice list runs a real model on the device through Apple's Foundation Models framework. It needs no backend or API key.

https://github.com/user-attachments/assets/c25184ad-aa7c-4159-bb89-db4033f4d2ce

`OnDeviceAgent.apple()` uses the same screen capabilities and approvals as a remote connection. Pass it to `TandemScope.connected` as `connection:`. It returns the same connection on each call, so it can be used in `build`.

The example selects the connection in its entry point:

<!-- example/lib/main_apple.dart -->
```dart
void main() => runApp(InvoiceApp(connection: OnDeviceAgent.apple()));
```

Build with Xcode 26 or newer. Generation requires iOS or macOS 26 on an eligible device, with Apple Intelligence enabled and its model downloaded. `OnDeviceAgent.apple().availability()` reports whether the model is available. Other platforms return `unsupportedPlatform` and can use an AG-UI backend instead. Use a supported Mac or physical iPhone for inference; the iOS simulator did not generate responses in our tests.

Responses arrive when generation finishes. Tandem does not trim conversation history. If a run fails with `OnDeviceErrorCode.contextWindowExceeded`, the app can handle that `RunFailed` event and call `session.startOver()` to clear the thread history. The failed message is not automatically retried. A `DateTime` parameter or a full tool schema the system rejects fails the run with `OnDeviceErrorCode.unsupportedSchema`. Some older systems reject nullable arguments, even when omitting them would give null.

Keep validation in the app's methods and approvals for changes that need the user's decision. [The invoice example](https://github.com/leancodepl/tandem/blob/main/example/README.md#smart-invoice-input-with-apples-on-device-model) has the run command. [The design notes](https://github.com/leancodepl/tandem/blob/main/doc/design.md#apple-on-device-connection) cover the other limits, native setup and test results.

## Your coding agent

`TandemBridge.enable()` registers two VM service extensions in a debug build. `ext.tandem.describe` lists the open screens and their available data and methods. `ext.tandem.call` calls a listed method. A profile or release build registers neither extension. Wrap each screen in a `TandemScope` whose `surface` provides the annotated state object, as shown in the [quick start](#quick-start).

A coding agent reaches the extensions through the `vm_service` tool of the Dart MCP server (`dart mcp-server`), or over HTTP at the VM service address printed by `flutter run`. The `tandem-coding-agent` skill describes both routes.

- The coding agent sees what an in-app agent would see, and calls only the listed methods, with the same checks.
- A call targets the front screen. This is the only open `TandemScope`, or the only one on the current route. If several screens match, the call must identify the screen.
- A `.callsWithApproval` call waits for the user to approve it in the app. The scope's `approvals:` setting controls how the request is shown. For scripted runs, `TandemBridge.enable(autoApprove: true)` lets the coding agent approve its own calls.

## An in-app agent

An in-app agent works with your app's users, in a chat or behind a button. Set `agent:` to an AG-UI backend that follows [the backend contract](#the-agent-backend). The [reference agents](https://github.com/leancodepl/tandem/tree/main/example/agents) show how to configure Google ADK, LangGraph and Pydantic AI. Put the chat next to the screen:

<!-- example/lib/order_screen.dart -->
```dart
    child: TandemScope(
      surface: (context) => context.read<OrderCubit>(),
      agent: Uri.parse('http://localhost:8000/agent'),
      approvals: const .fromState(),
      onEvent: showOrderMessages,
      child: const Row(
        children: [
          Expanded(child: OrderForm()),
          SizedBox(width: 360, child: AgentChat()),
        ],
      ),
    ),
```

The scope keeps its session across rebuilds. Removing the scope or changing its `agent`, connection or `thread` ends the session. `approvals: const .fromState()` lets the chat draw approval cards. [Events](#events) explains `onEvent`.

Tandem does not include a chat widget. You build the chat with your app's wording, language and styling. `TandemSessionScope.of(context)` returns the session and rebuilds the widget when the session changes. Each item in `session.items` is a sealed `ChatItem`:

<!-- example/lib/agent_chat.dart -->
```dart
  Widget build(BuildContext context) => switch (item) {
    // A message of session.wake is for the agent, not the user.
    UserMessage(fromApp: true) => const SizedBox.shrink(),
    UserMessage(:final text) => _Bubble(text, fromUser: true),
    AgentMessage(:final text, :final stopped) => _Bubble(
      text,
      stopped: stopped,
    ),
    ChatNotice(:final kind) => _Notice(kind),
    // A card of another call that lands at the same index gets a new state.
    final ApprovalRequest request => _ApprovalCard(
      request,
      approvalBuilder,
      key: ValueKey((session, request.toolCallId)),
    ),
  };
```

The example's [`AgentChat`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) is a complete chat widget you can copy. Its text field calls `session.send(text)`, and its button responds to [the session status](#session-status). The `tandem-in-app-agent` skill helps your coding agent build a chat or a button that sends a message.

## Views the agent draws

`TandemView` displays a view drawn by the in-app agent, such as an order summary or a list of order lines. Put one below a `TandemScope`, beside the screen or in place of part of the screen. The example's order desk puts the view below the form and limits it to half of that panel's height. On a phone, the panel shares the screen with the chat, so the summary has less room:

<!-- example/lib/desk/ui/order_desk_screen.dart -->
```dart
        const Expanded(child: OrderForm()),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
          child: const SingleChildScrollView(
            padding: .fromLTRB(12, 0, 12, 12),
            child: TandemView(),
          ),
        ),
```

<p align="center">
  <img src="https://github.com/leancodepl/tandem/raw/main/doc/imgs/examples/drawn-summary.png" alt="The order desk on an iPad: the order draft, and below it the summary that the agent drew, with its lines, a Remove button for each, the total and Place order." width="400">
</p>

While `TandemView` is attached, the agent can use `tandem_show_view`. Its description lists seven A2UI components: Text, Column, Row, List, Card, Divider and Button. There are no form fields.

- The model is instructed to bind screen data by path. Tandem checks those paths against `.sees`, and the bindings follow later screen changes. Literal text, such as a title, is also allowed.
- A button calls a listed method with the same checks and approvals as the agent's calls. `AgentCall` and `ApprovalRequest` identify the caller as `Caller.view`. A button that needs approval is enabled only when the session is `Idle` and the scope accepts approvals. Each button waits for its own call to finish before it can be pressed again.
- Pressing a button does not wake the agent. The method's result is included in `app_notes` for the next run. Call [`session.wake()`](#notes-from-the-app) from `onEvent` when the agent should respond.
- Tandem rejects an invalid view and tells the agent what to fix. This includes paths missing from `.sees`. The previous view remains visible, and the agent can retry in the same turn. After three consecutive refusals, Tandem tells the agent to answer in text and withholds `tandem_show_view` until the next user or app message.
- While the agent draws, the status is `Thinking(drawing: true)`.
- Use a strong remote model through an AG-UI backend that puts `context` into the model's prompt.
- `TandemView` provides no default content and takes no space before a view arrives. It does not scroll, so give it a scroll view when needed.
- A view is limited to 500 components, including repeated list items. If screen data grow beyond that policy ceiling, the view and its actions become unavailable and an English message shows. They return automatically when the screen data and listed methods fit the drawing again.

After the user places an order from the summary, the order desk's `onEvent` wakes the agent to respond:

<!-- example/lib/desk/ui/order_desk_screen.dart -->
```dart
void wakeOnPlacedOrder(
  BuildContext context,
  TandemEvent event,
  TandemSession session,
) {
  if (event case AgentCall(tool: 'place_order', caller: .view)) {
    session.wake();
  }
}
```

## Session status

`session.status` describes the session's current activity. `SessionStatus` is sealed, so a `switch` can cover every case:

<!-- example/lib/status_line.dart -->
```dart
final class const StatusLine({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (TandemSessionScope.of(context).status) {
        Idle() => const SizedBox.shrink(),
        Thinking(:final backendTool?) => Text('Using $backendTool…'),
        Thinking(drawing: true) => const Text('Drawing a view…'),
        Thinking() => const LinearProgressIndicator(),
        Calling(:final tool) => Text('Running $tool…'),
        AwaitingApproval(:final request) => Text(
          'Waiting for you: ${request.tool}',
        ),
        Stopping() => const Text('Stopping…'),
      };
}
```

`Thinking.backendTool` identifies the latest backend tool call, such as `find_customer`. It is set by `TOOL_CALL_START` and cleared when the result, the agent's next text or another call arrives. When backend tools run in parallel, this field reports the latest call. Use it to show progress during a long turn.

Call `session.stop()` while the status is `Thinking` or `Calling(approved: false)`. An approved method runs to completion. `Stopping` means the stopped run is still being read to its end, and new messages wait for it to finish.

## Approvals

A method listed with `.callsWithApproval` runs only after the user approves it. Approval is tied to the screen's `.sees` values, so list every value the method depends on. Changing a listed value permanently invalidates the request. A change outside `.sees`, such as a selected tab, leaves the request pending.

For an in-app agent, approval uses the `.sees` values from the start of the run. A change made by the agent's earlier calls invalidates that turn's requests, even before they appear. The agent must ask again after the change.

The agent receives the invalidation result in its next run, which starts with the user's next message. To have the agent ask again without another user message, call [`session.wake()`](#notes-from-the-app) after editing stops. The order desk waits one second after the last edit and wakes the agent only when this check returns `true`:

<!-- example/lib/desk/ui/order_desk_screen.dart -->
```dart
bool agentMustAskAgain(TandemSession session) => switch ([
  for (final item in session.items)
    if (item is ApprovalRequest || item is UserMessage) item,
].lastOrNull) {
  ApprovalRequest(status: .invalidated, caller: .inAppAgent) => true,
  _ => false,
};
```

The scope's `approvals:` setting controls how requests are shown:

| `approvals:` | For |
|---|---|
| `.fromState()` | a UI that draws the requests itself, from `session.items` or the status `AwaitingApproval(request)` |
| `.callback((context, request, session) async { ... })` | a dialog, a bottom sheet or anything imperative |
| `.none()` | a screen without `.callsWithApproval`: such a call is refused to the agent and reported in debug |

The [quick start](#quick-start) uses this dialog callback with `approvals: const .callback(confirmOrder)`:

<!-- example/lib/order_screen.dart -->
```dart
Future<void> confirmOrder(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final draft = context.read<OrderCubit>().draft;
  final place = await showDialog<bool>(
    context: context,
    builder: (context) => _PlaceOrderDialog(draft),
  );
  try {
    if (place ?? false) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // The order changed, or the screen closed, while the dialog showed.
  }
}
```

The dialog reads the draft from the Cubit. This is the same draft listed with `.sees`. If several methods need approval, use `request.tool` to choose the dialog's text.

- Approval requests from one turn appear one at a time. Rejecting a request cancels the remaining calls, and the agent can plan again.
- `approve` and `reject` apply the decision or throw `ApprovalNotPending`. Repeating the same decision does nothing, so a double tap is harmless. `session.isPending(request)` checks whether a request is still pending.
- A new user message cancels the pending request. If the callback leaves a request undecided, the request remains pending.
- Requests from a [coding agent](#your-coding-agent) use the same approval UI while the in-app agent waits. `request.caller` identifies who asked, so the card can explain what happens after invalidation.

## Events

The scope's `onEvent` callback receives session events as `TandemEvent` values, along with the scope's context and the session. `TandemEvent` is sealed, so a `switch` can cover every event:

<!-- example/lib/order_messages.dart -->
```dart
void showOrderMessages(
  BuildContext context,
  TandemEvent event,
  TandemSession session,
) {
  final message = switch (event) {
    AgentCall(tool: 'place_order', :final result) => 'Placed order $result.',
    RunFailed() || ConnectionLost() => 'The agent did not answer. Try again.',
    AgentCall() || RunStopped() => null,
  };
  if (message case final text?) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
```

`AgentCall` is emitted after a listed method returns, with its `tool`, `arguments`, `result` and `caller`. The caller is `Caller.inAppAgent`, `Caller.codingAgent` or `Caller.view` for a button in a [drawn view](#views-the-agent-draws). Refused calls and methods that throw do not emit `AgentCall`.

`RunFailed` and `ConnectionLost` add a `ChatNotice` to `session.items`. `RunStopped` reports a user stop or a backend cancellation. A stop adds a notice or marks the last agent message `stopped`.

When an error has a code, `RunFailed.code` contains a `RunErrorCode`. Match a specific error with a pattern such as `RunFailed(code: .unsupportedOutcome)`.

When the conversation history exceeds the model's context window, call `session.startOver()`. The next message starts a new AG-UI thread without that history. Existing chat items remain, and the chat adds a `startedOver` notice. Pending approval requests are cancelled. `startOver()` does nothing while a run or an approved method is in progress.

## Notes from the app

`session.note(text)` records what happened in the app outside the chat, such as an action the user took on the screen. Each run includes the latest five notes in the `app_notes` context entry. The entry separates new notes from earlier notes. Notes do not add chat items.

`session.wake()` asks the agent to respond to the app's notes. It sends a short `UserMessage` marked `fromApp`, which the [example chat](#an-in-app-agent) hides. If a run is active or an approval is pending, the wake waits. If the user stops the run that a wake was waiting for, that wake waits for the user's next message.

## Agent state

`session.agentState` exposes the backend's state for the current thread, such as its current step. AG-UI `STATE_SNAPSHOT` replaces this state, and `STATE_DELTA` applies a JSON Patch. Updates can arrive during a run, so a widget can show progress before the agent calls a method. This widget comes from a test in the example:

<!-- example/test/order_cubit_test.dart -->
```dart
final class const _AgentStep() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (TandemSessionScope.of(context).agentState) {
        {'step': final String step} => Text(step),
        _ => const SizedBox.shrink(),
      };
}
```

- The backend defines the state shape. Google ADK sends its session state, including internal keys starting with `_ag_ui_`. LangGraph sends the graph's output keys, with conversation history in `messages`. Pydantic AI sends state when a tool returns a `StateSnapshotEvent` or `StateDeltaEvent`, and reads state through `StateDeps`.
- Each run sends the current state back in AG-UI `state`, as `@ag-ui/client` does. This lets a stateless backend continue from the previous state. The app can read the state. To tell the agent what happened in the app, send a [note](#notes-from-the-app).
- A new thread starts with empty state. An invalid snapshot or delta leaves the previous state unchanged. Tandem reports the error and continues the run.
- In tests, use `AgentStep.stateSnapshot` and `AgentStep.stateDelta` with `ScriptedAgent` to send state updates.

## Keep the conversation

By default, each session starts a new thread. To keep a conversation when a screen closes, store its `TandemThread` outside the screen and pass it to `TandemScope(thread:)` when the screen reopens. The `State` of the page that opens the screen can own the thread. The next session restores the chat, conversation history and agent state. `session.thread.id` is the AG-UI thread ID.

- Only the newest session uses a thread. The previous session detaches, even if its screen is still animating out. Conversations across different screens are not supported yet.
- A thread can resume on the same screen. Before the first message, Tandem compares the screen's `.sees` values with those saved when the screen closed. Different values reset the thread and add a `startedOver` notice. Keep the state object for as long as the thread to preserve the conversation and screen state together.
- Closing a screen during a run or an approved method also resets the thread. The backend may finish work whose results the app never receives. Closing a screen with a pending approval cancels the request. The agent receives the `cancelled` result with the next message.
- Changing `agent` carries the thread, history and agent state to the new backend. Pass a new `TandemThread` to start a separate conversation.
- Threads live in memory and are lost when the app restarts. Tandem does not persist them yet.

## Any state library

Tandem gets the state object through `surface` and listens to its `changes` stream. No state-library adapter is required. The stream must be a broadcast stream with an event for every change:

| State | `changes` |
|---|---|
| bloc's `Cubit` | `stream` |
| `ChangeNotifier` or `ValueNotifier` | a `StreamController.broadcast()` that an override of `notifyListeners` feeds |
| Riverpod's `Notifier` | a `StreamController.broadcast()` that `listenSelf` in `build` feeds |

The example's invoice list uses a `ChangeNotifier`:

<!-- example/lib/invoices/invoice_store.dart -->
```dart
  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _changes.add(null);
  }
```

`_changes` is a `StreamController<Object?>.broadcast()`, so a new session can subscribe again. A `ChangeNotifier` closes the controller in `dispose()`.

A Riverpod `Notifier` can feed the stream through `listenSelf((_, next) => _changes.add(next))` in `build`. Riverpod removes the listener before rebuilding the provider. Keep the controller open across rebuilds. Do not close it in `ref.onDispose`, which runs before every rebuild.

Use `surface` to read the state object, for example with `context.read<InvoiceStore>()` or `ref.read(cartProvider.notifier)` in a Riverpod `ConsumerWidget`. Put the scope below the state object's owner so the session is disposed first. `riverpod_generator` cannot annotate the same class as `tandem_generator`, because both generate a `_$Name` mixin.

## Testing

`ScriptedAgent` from `package:tandem/testing.dart` returns scripted responses, so widget tests need no model or backend. Pass the agent as `connection:` to `TandemScope.connected`. Here `cubit` is an `OrderCubit` created in `setUp`:

<!-- example/test/order_cubit_test.dart -->
```dart
  testWidgets('the agent sets a quantity from the chat', (tester) async {
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

Each function in the script produces one run. A run past the finite script ends with `RUN_ERROR`. For a demo that handles each run with the same callback, use `ScriptedAgent.repeating(turn)`. `agent.requests` records every raw request body.

Inside a callback, `AgentRequest(raw)` reads named JSON context with `context(name)`, offered tools with `offersTool(name)` and new app notes with `newNotes`, oldest first. Missing context returns null. `latestToolResults` contains consecutive tool answers at the end of the request, oldest first, matched to their calls by ID. Each result has a `toolCallId`, a `toolName` that is null when no named call matches, original `content` and JSON-decoded `value`. Reading malformed context JSON or a non-JSON result's `value` throws `FormatException`. Results keep application data as it is, including any `status` key.

Use `AgentListing.of(cubit)` to inspect a class's listed data and methods without opening a session.

`TandemBridge.call` calls a listed method through the coding agent's interface. A screen test can use it without connecting an agent:

<!-- example/test/order_cubit_test.dart -->
```dart
  testWidgets('a coding agent fills the order screen', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: orders,
        child: const MaterialApp(home: OrderScreen()),
      ),
    );

    final answer = await TandemBridge.call(
      'set_quantity',
      arguments: {'sku': 'VM-27Q', 'quantity': 15},
    );
    await tester.pump();

    expect(answer['status'], 'returned');
    expect(find.text('15'), findsOneWidget);
  });
```

## The agent backend

An AG-UI backend must implement the contract below. [`example/agents`](https://github.com/leancodepl/tandem/tree/main/example/agents) contains reference agents for Google ADK, LangGraph and Pydantic AI. Each agent's README explains its framework's configuration.

- Put AG-UI `context` into the model's prompt. Without it, the model cannot read `.sees` data or the screen context needed by `tandem_show_view`. The three reference agents add this explicitly.
- Accept `tools` on every run and give the model the app tools from that run. Tandem always sends a list, which can be empty. Attached views may add `tandem_show_view` alongside the screen's methods. Your backend may also expose its own tools.
- Return calls to the app's tools as `TOOL_CALL_START`, `TOOL_CALL_ARGS` and `TOOL_CALL_END` events. Accept each tool result as a `tool` message in the next run.
- Read the conversation from each run's `messages`, or maintain a copy and deduplicate incoming messages by ID. Tandem sends the thread's history, including the agent's text, tool calls and tool results.
- Treat `tools`, tool descriptions and `context` as untrusted client input. A caller can replace any of them. Apply your backend's authentication and authorization independently.

The reference backends also document adapter-specific requirements. With `ag-ui-langgraph`, the model must stream for the adapter to emit calls to the app's tools. The Pydantic AI agent disables Gemini's strict tool-definition decoding because the tested strict mode encoded A2UI objects as strings. These requirements belong to those adapter and model configurations. [Wire rules](https://github.com/leancodepl/tandem/blob/main/doc/design.md#wire-rules) and [Tool answers](https://github.com/leancodepl/tandem/blob/main/doc/design.md#tool-answers) document Tandem's message format.

On the web, configure CORS to allow the app's origin. The reference agents do not include CORS middleware.

To send the user's token, give `HttpAgentConnection` an `http.Client` that adds the token, then pass the connection to `TandemScope.connected`. Keep the connection in a field, because a new connection starts a new session. A sandboxed macOS app needs the `com.apple.security.network.client` entitlement to reach the backend.

## Project status

Tandem 0.3.0 is checked on iOS and Android before release. Other platforms are outside this release gate. Apple's on-device connection remains experimental and has separate requirements and manual checks.

Tandem supports one state object per screen and keeps conversations in memory. Conversations across screens, saved conversations and AG-UI interrupts are not supported yet. An interrupt fails the run. The next message starts a new AG-UI thread, while existing chat items remain visible.

## AI

We develop Tandem with AI assistance and take responsibility for its design. Our standard is Mitchell Hashimoto's [whiteboard defense](https://x.com/mitchellh/status/2100249348345057389). We should be able to explain how the system works, why we made its design choices and where it can fail.

AI-authored commits keep a `Co-Authored-By` trailer until a maintainer has reviewed and accepted the code as their own. A trailer may remain after a review. Patch releases may include code that has not yet completed that process. Before a minor release, we review the accumulated changes and their design decisions.

## 🛠️ Maintained by LeanCode

<div align="center">

  [<img src="https://leancodepublic.blob.core.windows.net/public/wide.png" alt="LeanCode Logo" height="100" />][leancode-landing]

</div>

This package is built with 💙 by **[LeanCode][leancode-landing]**.
We are **top-tier experts** focused on Flutter Enterprise solutions.

### Why LeanCode?

- **Creators of [Patrol][patrol-landing]** – the next-gen testing framework for Flutter.
- **Full-Cycle Product Development** – we take your product from scratch to long-term maintenance.

<div align="center">
  <br />

  **Need help with your Flutter project?**

  [**👉 Hire our team**][leancode-estimate]
  &nbsp;&nbsp;•&nbsp;&nbsp;
  [Check our other packages][leancode-packages]

</div>

Licensed under the [Apache License 2.0](./LICENSE).

[leancode-landing]: https://leancode.co/?utm_source=github.com&utm_medium=referral&utm_campaign=tandem
[leancode-estimate]: https://leancode.co/get-estimate?utm_source=github.com&utm_medium=referral&utm_campaign=tandem
[leancode-packages]: https://pub.dev/packages?q=publisher%3Aleancode.co&sort=downloads
[patrol-landing]: https://patrol.leancode.co/?utm_source=github.com&utm_medium=referral&utm_campaign=tandem
