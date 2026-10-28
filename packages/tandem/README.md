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

Start with your coding agent: in 10 minutes, it fills a form of your running app through the setters your buttons already call. No backend, no API key. Give Claude Code this prompt in your app's folder:

```text
Run `dart run skills@ add leancodepl/tandem --skill tandem --agent claude`, then read `.claude/skills/tandem/SKILL.md` and follow it.
```

In a new session, `/tandem` does the same. Tandem is tested with Claude Code only. Cursor and Codex should work the same way, but you set them up on your own: use `--agent cursor` and `.cursor/skills/tandem/SKILL.md`, or `--agent codex` and `.agents/skills/tandem/SKILL.md`.

Pick a screen. Its state class lists what an AI agent may see and which of its methods the agent may call. The agent then works on that screen together with the user, through the methods your buttons already call, and the important ones wait for the user's approval. Where you put a `TandemView`, the agent can also draw for the user, such as a summary of the order with a button that places it. The rest of the app stays as it is.

## How it works

![The Flutter app with tandem sends the agent backend the user's message, what the agent sees and what it may call, over AG-UI. The backend keeps the API key, asks the model, and sends back replies, calls to the app's methods and views in A2UI, which TandemView draws. On iOS and macOS 26, OnDeviceAgent does the same with Apple's on-device model, without a backend or an API key.](https://github.com/leancodepl/tandem/raw/main/doc/imgs/how-it-works.svg)

With a remote agent, your backend calls the model and keeps the API key. The app talks to it over [AG-UI](https://docs.ag-ui.com), an open protocol between agents and apps. Google ADK, LangChain, CrewAI, Mastra and many other agent frameworks support it.

On iOS and macOS 26, the experimental `OnDeviceAgent` can run [Apple's on-device model](#apples-on-device-model) instead, without a backend or an API key, for the simplest tasks. The screen, its capabilities and approvals stay the same.

In a debug build, [your coding agent](#your-coding-agent), such as Claude Code, calls the same methods through `TandemBridge`, with the same checks and approvals.

The in-app agent can also draw a view for the user in [A2UI](https://a2ui.org), an open protocol for views that agents draw. The view comes as a call of Tandem's tool `tandem_show_view`, and [`TandemView`](#views-the-agent-draws) draws it from the screen's data, with buttons that call the screen's methods.

Your state class lists what the agent may do:

<!-- example/lib/order_cubit.dart -->
```dart
  List<AgentCapability> get agentCapabilities => [
    .sees(draft),
    .calls(setQuantity),
    if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
  ];
```

- `.sees(draft)`: the agent sees the draft as it is at each turn, and nothing the class does not list.
- `.calls(setQuantity)`: the agent calls the method a button calls, so the same validation runs and the screen changes as after a tap.
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

   The agent gets exactly what is on the list, with the doc comments, and the parameter types become the schema. The list is read again before every turn, so it can depend on the state or on who the user is. `changes` reports every change, here the Cubit's `stream`. Not on bloc? [Any state library](#any-state-library) shows the same with provider and Riverpod.

3. Generate the code:

   ```sh
   dart run build_runner build
   ```

   Every class with `@TandemAgent()` gets a `_$Name` mixin. Each `.sees` stands directly in the list, not inside an `if`, a `for`, a `?:` or a spread, or the build fails. In CI, run `dart run build_runner build && git diff --exit-code`: an outdated `.g.dart` is not always caught at runtime.

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

   The scope reads the Cubit with `surface` when it opens its session. `confirmOrder` shows a dialog in which the user approves or rejects `placeOrder` ([Approvals](#approvals)). The scope has no in-app agent: [An in-app agent](#an-in-app-agent) adds one.

5. Let your coding agent fill it. One line in `main()` opens the screens of a debug build to it:

   <!-- example/lib/main.dart -->
   ```dart
   void main() {
     TandemBridge.enable();
     runApp(const OrderDeskApp());
   }
   ```

   Run the app in debug and ask your coding agent to fill the order, such as from an e-mail. [Your coding agent](#your-coding-agent) explains how it reaches the app.

> [!TIP]
> `/tandem` from the prompt above walks your coding agent through these steps. `dart run skills@ get --package tandem --all` installs the skills of your version of Tandem: the base steps, the coding agent and the in-app agent.

## Try it without a key

<p align="center">
  <a href="https://github.com/leancodepl/tandem/blob/main/example/README.md#smart-invoice-input-with-apples-on-device-model"><img src="https://github.com/leancodepl/tandem/raw/main/doc/imgs/examples/smart-input-film.gif" alt="Two invoices picked by hand, then one sentence finds all six from May on Apple's on-device model, and the app asks before it archives them." width="400"></a>
</p>

The [example](https://github.com/leancodepl/tandem/blob/main/example/README.md) runs an order desk on Android, iOS and macOS with a scripted agent, without a backend or an API key. It can also talk to the example's agent backend, which has a scripted model too. On a Mac or an iPhone with Apple Intelligence, the [invoice list](https://github.com/leancodepl/tandem/blob/main/example/README.md#smart-invoice-input-with-apples-on-device-model) above runs on Apple's on-device model, a real model that needs no key.

The order desk enables `TandemBridge`, so your coding agent can fill the order too. To try your own screen without a backend, give `TandemScope.connected` a `ScriptedAgent`, as [the order desk](https://github.com/leancodepl/tandem/blob/main/example/lib/desk/order_desk_agent.dart) does.

## Your coding agent

`TandemBridge.enable()` registers two VM service extensions in a debug build. `ext.tandem.describe` gives the open screens, with what the agent sees and may call. `ext.tandem.call` calls one of the listed methods. A profile or release build registers nothing.

A coding agent reaches them with the `vm_service` tool of the Dart MCP server (`dart mcp-server`), or over HTTP at the VM service address that `flutter run` prints. The skill `tandem-coding-agent` teaches it both.

- The coding agent sees what an in-app agent would see, and calls only the listed methods, with the same checks.
- A call goes to the front screen: the only open `TandemScope`, or else the only one on the current route. When there are several, the call names one.
- A `.callsWithApproval` method waits until the user approves it in the app, as `approvals:` of the scope asks. `TandemBridge.enable(autoApprove: true)` lets the coding agent approve its own calls, for a scripted run.

## An in-app agent

An in-app agent works with your app's users, in a chat or behind a button. Give the scope the address of your AG-UI backend as `agent:`, and put the chat next to the screen:

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

The scope keeps its session until it leaves the tree or gets another `agent`. `approvals: const .fromState()` lets the chat draw the approval cards, and [Events](#events) explains `onEvent`.

Tandem has no chat widget, so the chat has your app's texts, language and look. `TandemSessionScope.of(context)` gives the session and rebuilds the widget when it changes. Each item of `session.items` is a sealed `ChatItem`:

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

[`AgentChat`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the example is the whole chat in one file, ready to copy. Its field calls `session.send(text)`, and its button switches on [the status](#session-status). The skill `tandem-in-app-agent` builds the chat, or a button, with your coding agent.

## Views the agent draws

`TandemView` shows what the in-app agent draws for the user, such as a card with the order and its total, or a table of its lines. Put it below the scope, next to the screen or in place of a part of it. The order desk of the example puts it below its form, in at most half of the height:

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

While `TandemView` is on the screen, every run offers the agent the tool `tandem_show_view`, whose description teaches it seven A2UI components: Text, Column, Row, List, Card, Divider and Button. There are no form fields.

- The texts show only what `.sees` lists, by path, so the view follows the screen without the agent.
- A button calls a method the screen lists, with the same checks and approvals as the agent's calls, and `caller: Caller.view` in `AgentCall` and `ApprovalRequest`. A button of a `.callsWithApproval` method is enabled only while the session is `Idle`, and a button waits for its own call to answer. A press wakes no agent: the agent reads what the method answered in `app_notes` with its next run, and `onEvent` may call [`session.wake()`](#notes-from-the-app).
- A view that does not fit the screen, such as one with a path that `.sees` does not have, is refused with what to fix, and the agent fixes it in the same turn. The last view stays.
- While the agent draws, the status is `Thinking(drawing: true)`.
- Drawing needs a strong remote model, such as Gemini, behind an AG-UI backend that puts `context` into the prompt. A small local model or Apple's on-device model rarely writes valid A2UI.
- `TandemView` has no texts of its own, takes no space before the agent draws and does not scroll.

Once the user placed the order from the summary, the order desk's `onEvent` lets the agent answer:

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

`session.status` says what the session does now. It is sealed, so a `switch` covers every case:

<!-- example/lib/status_line.dart -->
```dart
final class const StatusLine({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (TandemSessionScope.of(context).status) {
        Idle() => const SizedBox.shrink(),
        Thinking(:final backendTool?) => Text('Using $backendTool…'),
        Thinking() => const LinearProgressIndicator(),
        Calling(:final tool) => Text('Running $tool…'),
        AwaitingApproval(:final request) => Text(
          'Waiting for you: ${request.tool}',
        ),
        Stopping() => const Text('Stopping…'),
      };
}
```

`Thinking` names the tool of the agent's backend that runs now, such as `search_catalog`, from its `TOOL_CALL_START` until its result or the agent's next text or call, so a long turn can say what the agent does.

Stop is available while the status is `Thinking`, or `Calling` a method the user did not approve. An approved method runs to its end.

## Approvals

A method listed with `.callsWithApproval` runs only after the user approves it. The approval covers what the agent saw when it asked, so list everything the method depends on with `.sees`. When a value listed with `.sees` changes, Tandem invalidates the request for good and the agent has to ask again. This holds from the start of the agent's run: a change made by the agent's own calls of that turn invalidates the turn's requests before they show. A change outside `.sees`, such as a selected tab, leaves it pending.

`approvals:` on the scope says how the screen asks:

| `approvals:` | For |
|---|---|
| `.fromState()` | a UI that draws the requests itself, from `session.items` or the status `AwaitingApproval(request)` |
| `.callback((context, request, session) async { ... })` | a dialog, a bottom sheet or anything imperative |
| `.none()` | a screen without `.callsWithApproval`: such a call is refused to the agent and reported in debug |

The dialog of the [quick start](#quick-start), which passes `approvals: const .callback(confirmOrder)`:

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

The dialog shows the draft from the Cubit, because the approval covers what `.sees` lists. With several methods that need approval, pick the dialog's text by `request.tool`.

- Several approvals of one turn show one at a time. A rejection cancels the rest, and the agent plans again.
- `approve` and `reject` either decide or throw `ApprovalNotPending`. The same decision twice does nothing, so a double tap is harmless. `session.isPending(request)` tells whether a request still waits.
- A message the user sends while a request waits cancels it. A request the callback leaves undecided waits until then.
- A request of a [coding agent](#your-coding-agent) shows the same way, while the in-app agent does nothing. `request.caller` says who asked, so an invalidated card can say whom to ask again.

## Events

`onEvent` on the scope hears what happens in the session, as a sealed `TandemEvent`. It gets the scope's context and the session:

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

`AgentCall` comes after a listed method returned, with its `tool`, `arguments`, `result` and `caller`: `Caller.inAppAgent`, `Caller.codingAgent` or `Caller.view`, a press on a button of a [drawn view](#views-the-agent-draws). `RunFailed` and `ConnectionLost` also add a `ChatNotice` to `session.items`, and a stop adds one or marks the last message `stopped`.

`RunFailed` has the error's `code` when it has one, a `RunErrorCode` that a pattern such as `RunFailed(code: .unsupportedOutcome)` matches. When the history no longer fits the model, `session.startOver()` sends the next message to a new thread without it. The chat keeps its items and adds a `startedOver` notice. It does nothing while a run is open.

## Notes from the app

`session.note(text)` tells the agent what happened in the app outside the chat, such as what the user did on the screen. Every run gives the agent the latest five notes in one `context` entry, `app_notes`, split into what is new since its last turn and what came earlier. The chat shows nothing.

`session.wake()` lets the agent take a turn on it. It sends a short message that says it comes from the app: a `UserMessage` with `fromApp` set, which the chat above hides. It never decides for the user: while a run is open or a request waits, it waits, and after a Stop it goes with the user's next message.

## Any state library

Tandem reads the state object with `surface` and hears it change in `changes`, so a state library needs no adapter package. `changes` is a broadcast stream with an event for every change:

| State | `changes` |
|---|---|
| bloc's `Cubit` | `stream` |
| `ChangeNotifier` or `ValueNotifier` | a `StreamController.broadcast()` that an override of `notifyListeners` feeds |
| Riverpod's `Notifier` | a `StreamController.broadcast()` that `listenSelf` in `build` feeds |

A `ChangeNotifier`, from the invoice list of the example:

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

`_changes` is a `StreamController<Object?>.broadcast()`: every new session listens again. A Riverpod `Notifier` feeds it with `listenSelf((_, next) => _changes.add(next))` in `build`, a listener that Riverpod drops when it builds again. Do not close the controller in `ref.onDispose`: Riverpod calls that before every rebuild of the provider.

`surface` reads the object from the scope's context, such as `context.read<InvoiceStore>()`, or `ref.read(cartProvider.notifier)` in a Riverpod `ConsumerWidget`. Put the scope below what owns the object, so the scope disposes its session first. `riverpod_generator` cannot be used on the same class: it writes a `_$Name` too.

## Testing

`ScriptedAgent` from `package:tandem/testing.dart` plays a script instead of a model, so widget tests run without a backend. `TandemScope.connected` takes it in place of the endpoint. Here `cubit` is an `OrderCubit` from `setUp`:

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

Every turn of the script is one run. `agent.requests` holds the body of every run, so a test can check what the agent saw. To check only what a class gives the agent, use `AgentListing.of(cubit)`.

`TandemBridge.call` calls a listed method as a coding agent does, so a test of the screen needs no agent at all:

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

Any AG-UI endpoint works. The backend has to:

- Put the AG-UI `context` into the model's prompt. ag-ui-adk does not, so its agent needs an instruction provider that adds it.
- Accept `tools` on every run. Tandem always sends it, an empty list when no method is listed.
- On the web, allow the app's origin with CORS.
- Treat the `tools`, their descriptions and the `context` as untrusted input: they come from the app, and anyone can send a run with other ones.

To send the user's token, give `HttpAgentConnection` an `http.Client` that adds it, and pass the connection to `TandemScope.connected`. Keep the connection in a field: a new one starts a new session. A sandboxed macOS app needs the `com.apple.security.network.client` entitlement to reach the agent. [`example/agent`](https://github.com/leancodepl/tandem/tree/main/example/agent) is a Google ADK agent to copy from.

## Apple's on-device model

> [!WARNING]
> Experimental. Apple's on-device model is small, so use it for the simplest tasks, such as one sentence that becomes one call. It is not part of what Tandem checks before a release.

`OnDeviceAgent.apple()` runs Apple's system model on the device, with the same screen, capabilities, chat and approvals as a remote agent. Pass it to `TandemScope.connected`. It returns the same connection on every call, so `build` may call it.

The invoice list of the example runs on it:

<!-- example/lib/main_apple.dart -->
```dart
void main() => runApp(InvoiceApp(connection: OnDeviceAgent.apple()));
```

Build with Xcode 26 or newer. To generate, the app needs iOS or macOS 26 on an eligible device, with Apple Intelligence on and its model ready. `await OnDeviceAgent.apple().availability()` says which of these is missing. Other platforms answer `unsupportedPlatform` and keep using remote connections. Native registration works with Swift Package Manager and CocoaPods.

Unlike a remote agent, the text comes whole when the model finishes. Nothing shortens the history: once it no longer fits the model, the run fails with `OnDeviceErrorCode.contextWindowExceeded`, and [`session.startOver()`](#events) goes on without it. A `DateTime` parameter fails the run with `OnDeviceErrorCode.unsupportedSchema`. [The design](https://github.com/leancodepl/tandem/blob/main/doc/design.md#apple-on-device-connection) has the other limits and how they were tested.

The model can still pick the wrong call, so keep the same validation and approvals as for a remote model. The Swift side has not had a human review yet ([AI](#ai)).

## Project status

Not supported yet: AG-UI interrupts, several state objects on one screen, and a conversation that goes on across screens. A run that ends with an interrupt fails, and the next message starts a new conversation.

## AI

Tandem is written with AI assistance and reviewed by hand, except the Swift side of `OnDeviceAgent` ([`packages/tandem/darwin`](https://github.com/leancodepl/tandem/tree/main/packages/tandem/darwin)), which has not had a human review. Tandem carries its own bridge to Apple's model for now, because no package fits yet: the ones on pub.dev run tools natively, where Tandem needs to run them itself with approvals, and drop JSON Schema it needs, such as nullable unions. As with AG-UI instead of a protocol of its own, Tandem will consider switching to such a package once there is one.

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
