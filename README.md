<p align="center">
  <img src="https://github.com/leancodepl/tandem/raw/main/doc/imgs/logo.png" alt="tandem: a robot and Dash riding a tandem bike" width="400">
</p>

<br>

# tandem

<p>
  <a href="https://pub.dev/packages/tandem"><img src="https://img.shields.io/pub/v/tandem?style=for-the-badge&logo=dart" alt="tandem on pub.dev"></a>
  <a href="https://github.com/leancodepl/tandem/actions/workflows/test.yml"><img src="https://img.shields.io/github/actions/workflow/status/leancodepl/tandem/test.yml?branch=main&style=for-the-badge&logo=github" alt="Test status"></a>
  <a href="https://github.com/leancodepl/tandem/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-green?style=for-the-badge" alt="License: Apache 2.0"></a>
  <a href="https://pub.dev/packages/leancode_lint"><img src="https://img.shields.io/badge/style-leancode__lint-f0ff00?style=for-the-badge" alt="style: leancode_lint"></a>
</p>

Add an AI agent to your Flutter screens. It works on the screen together with the user, conveniently.

## How it works

![The Flutter app with tandem sends the agent backend the user's message, what the agent sees and what it may call, over AG-UI. The backend keeps the API key, asks the model, and sends back replies and calls to the app's methods.](https://github.com/leancodepl/tandem/raw/main/doc/imgs/how-it-works.svg)

The model does not run in the app. Your agent backend calls it and keeps the API key, and the app talks to the backend over [AG-UI](https://docs.ag-ui.com), an open protocol between agents and apps. Google ADK, LangChain, CrewAI, Mastra and many other agent frameworks support it. Tandem is the app's side.

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

4. Wrap the screen and its chat:

   <!-- example/lib/order_screen.dart -->
   ```dart
   final class const OrderScreen({super.key}) extends StatelessWidget {
     @override
     Widget build(BuildContext context) => BlocProvider(
       create: (context) => OrderCubit(orders: context.read<Orders>()),
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
     );
   }
   ```

   The scope reads the Cubit with `surface` when it opens its session, and keeps the session until it leaves the tree or gets another `agent`. [Approvals](#approvals) and [Events](#events) explain the other two lines.

5. Build the chat. Tandem has no chat widget, so the chat has your app's texts, language and look. `TandemSessionScope.of(context)` gives the session and rebuilds the widget when it changes. Each item of `session.items` is a sealed `ChatItem`:

   <!-- example/lib/agent_chat.dart -->
   ```dart
     Widget build(BuildContext context) => switch (item) {
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

   [`AgentChat`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the example is the whole chat in one file, ready to copy. Its field calls `session.send(text)`, and its button switches on [the status](#session-status).

> [!TIP]
> Setting this up with a coding agent? `dart run skills@ get` installs Tandem's skill from your dependencies, and the agent follows these steps.

## Try it without a key

<p align="center">
  <a href="https://github.com/leancodepl/tandem/blob/main/example/README.md"><img src="https://github.com/leancodepl/tandem/raw/main/doc/imgs/examples/approval.gif" alt="The agent asks to empty a shopping list. Removing an item invalidates the request, and a new request can be approved." width="300"></a>
</p>

The [example gallery](https://github.com/leancodepl/tandem/blob/main/example/README.md) runs six screens on Android, iOS and macOS with scripted agents, without a backend or an API key. Its order desk can also talk to the example's agent backend, which has a scripted model too.

To try your own screen without a backend, give `TandemScope.connected` a `ScriptedAgent` ([how](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#without-an-api-key)). [More examples](https://github.com/leancodepl/tandem/blob/main/doc/examples.md) have screens to copy with bloc, Riverpod and provider.

## Session status

`session.status` says what the session does now. It is sealed, so a `switch` covers every case:

<!-- example/lib/status_line.dart -->
```dart
final class const StatusLine({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (TandemSessionScope.of(context).status) {
        Idle() => const SizedBox.shrink(),
        Thinking() => const LinearProgressIndicator(),
        Calling(:final tool) => Text('Running $tool…'),
        AwaitingApproval(:final request) => Text(
          'Waiting for you: ${request.tool}',
        ),
        Stopping() => const Text('Stopping…'),
      };
}
```

Stop is available while the status is `Thinking`, or `Calling` a method the user did not approve. An approved method runs to its end.

## Approvals

A method listed with `.callsWithApproval` runs only after the user approves it. The approval covers what the agent saw when it asked, so list everything the method depends on with `.sees`. When a value listed with `.sees` changes, Tandem invalidates the request for good and the agent has to ask again. This holds from the start of the agent's run: a change made by the agent's own calls of that turn invalidates the turn's requests before they show. A change outside `.sees`, such as a selected tab, leaves it pending.

`approvals:` on the scope says how the screen asks:

| `approvals:` | For |
|---|---|
| `.fromState()` | a UI that draws the requests itself, from `session.items` or the status `AwaitingApproval(request)` |
| `.callback((context, request, session) async { ... })` | a dialog, a bottom sheet or anything imperative |
| `.none()` | a screen without `.callsWithApproval`: such a call is refused to the agent and reported in debug |

A dialog, from [an example](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#an-approval-dialog) that passes `approvals: const .callback(_confirmSend)`:

<!-- example/lib/recipes/approval_dialog/reply_screen.dart -->
```dart
Future<void> _confirmSend(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final reply = context.read<ReplyCubit>().reply;
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => _SendDialog(reply),
  );
  try {
    if (send ?? false) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // The reply changed, or the screen closed, while the dialog showed.
  }
}
```

- Several approvals of one turn show one at a time. A rejection cancels the rest, and the agent plans again.
- `approve` and `reject` either decide or throw `ApprovalNotPending`. The same decision twice does nothing, so a double tap is harmless. `session.isPending(request)` tells whether a request still waits.
- A message the user sends while a request waits cancels it. A request the callback leaves undecided waits until then.

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

`AgentCall` comes after a listed method returned, with its `tool`, `arguments` and `result`. `RunFailed` and `ConnectionLost` also add a `ChatNotice` to `session.items`, and a stop adds one or marks the last message `stopped`.

## Any state library

Tandem reads the state object with `surface` and hears it change in `changes`, so a state library needs no adapter package. `changes` is a broadcast stream with an event for every change:

| State | `changes` |
|---|---|
| bloc's `Cubit` | `stream` |
| `ChangeNotifier` or `ValueNotifier` | a `StreamController.broadcast()` that an override of `notifyListeners` feeds |
| Riverpod's `Notifier` | a `StreamController.broadcast()` that `listenSelf` in `build` feeds |

With provider and a `ChangeNotifier`:

<!-- example/lib/recipes/change_notifier/todo_list.dart -->
```dart
@TandemAgent()
class TodoList() extends ChangeNotifier with _$TodoList {
  final _changes = StreamController<Object?>.broadcast();
  final _todos = <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(todos),
    .calls(add),
    if (todos.isNotEmpty) .callsWithApproval(clear),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _changes.add(null);
  }

  /// The to-dos as the user sees them, oldest first.
  List<String> get todos => List.unmodifiable(_todos);

  /// Adds [todo] at the end of the list.
  void add(String todo) {
    _todos.add(todo);
    notifyListeners();
  }

  /// Removes every to-do.
  void clear() {
    _todos.clear();
    notifyListeners();
  }
}
```

With Riverpod:

<!-- example/lib/recipes/riverpod/cart_notifier.dart -->
```dart
  List<String> build() {
    // Riverpod drops this listener when it builds again, so it is never
    // there twice.
    listenSelf((_, next) => _changes.add(next));
    return const [];
  }
```

`surface` reads the object from the scope's context, such as `context.read<TodoList>()`, or `ref.read(cartProvider.notifier)` in a Riverpod `ConsumerWidget`. Put the scope below what owns the object, so the scope disposes its session first. `riverpod_generator` cannot be used on the same class: it writes a `_$Name` too. [The examples](https://github.com/leancodepl/tandem/blob/main/doc/examples.md) have a screen for each.

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

## The agent backend

Any AG-UI endpoint works. The backend has to:

- Put the AG-UI `context` into the model's prompt. ag-ui-adk does not, so its agent needs an instruction provider that adds it.
- Accept `tools` on every run. Tandem always sends it, an empty list when no method is listed.
- On the web, allow the app's origin with CORS.
- Treat the `tools`, their descriptions and the `context` as untrusted input: they come from the app, and anyone can send a run with other ones.

To send the user's token, give `HttpAgentConnection` an `http.Client` that adds it, and pass the connection to `TandemScope.connected` ([example](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#a-token-for-your-backend)). A sandboxed macOS app needs the `com.apple.security.network.client` entitlement to reach the agent. [`example/agent`](https://github.com/leancodepl/tandem/tree/main/example/agent) is a Google ADK agent to copy from.

## Project status

Not supported yet: AG-UI interrupts, several state objects on one screen, and a conversation that goes on across screens. A run that ends with an interrupt fails, and the next message starts a new conversation.

## AI

Tandem is written with AI assistance and reviewed by hand, except the AG-UI protocol layer ([`packages/tandem/lib/src/protocol`](https://github.com/leancodepl/tandem/tree/main/packages/tandem/lib/src/protocol)) and [`tandem_generator`](https://pub.dev/packages/tandem_generator), which have not had a full human review yet.

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
