---
name: tandem-agent-aware-screen
description: Make a Flutter screen agent-aware with Tandem, so an AI agent sees what the screen shows, calls the methods of its state class (a Cubit, a Riverpod Notifier or a ChangeNotifier), and anything that matters waits for the user's approval. Use when asked to add an AI agent, assistant or copilot to a Flutter screen, or when the code uses TandemScope, TandemSessionScope, @TandemAgent or agentCapabilities.
---

# Make a screen agent-aware with Tandem

Tandem works on a screen that already has a state class: a Cubit, a Riverpod `Notifier`, a `ChangeNotifier`, or any class that can report its changes. The agent sees what the class lists with `.sees` and acts only through the methods it lists, the same ones the screen's buttons call. The steps use a Cubit. [The examples](https://github.com/leancodepl/tandem/blob/main/doc/examples.md) show the same for Riverpod and provider. Do the steps in order and check each "Done when" before the next.

## 1. Add the packages

```sh
flutter pub add tandem
flutter pub add dev:build_runner dev:tandem_generator
```

Needs Dart 3.13 (Flutter 3.47) or newer.

**Done when** `flutter pub get` succeeds.

## 2. List what the agent may see and call

In the screen's state class, here a Cubit:

```dart
part 'order_cubit.g.dart';

@TandemAgent()
class OrderCubit extends Cubit<OrderState> with _$OrderCubit {
  // The constructor stays as it is.

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
  void setQuantity(String sku, int quantity) { ... }

  /// Places the order exactly as it is on the screen.
  Future<OrderId> placeOrder() async { ... }
}
```

- `.sees(getter)`: a getter of this class. List only what the user sees on the screen.
- `.calls(method)`: a method of this class that a button already calls, so the same validation runs for both.
- `.callsWithApproval(method)`: anything the user cannot easily undo, that costs money or that sends something. It runs only after the user taps Approve. The approval covers only what is listed with `.sees`, so list everything the method depends on. A change to those values after the agent's run started invalidates the request before it shows, also a change made by the agent's own calls in the same turn.
- The list is read again before every turn and every call, so an `if` can hide a method.
- `changes` reports every change of the class as a broadcast stream. On each change Tandem checks the `.sees` values, and a card whose values changed is invalidated while the user looks at it. Other changes leave the card alone. A Cubit returns its `stream`. A Riverpod `Notifier` adds each state to a `StreamController.broadcast()` from `listenSelf` in `build`. A `ChangeNotifier` adds to one in an override of `notifyListeners`.
- Every listed getter and method needs a doc comment written for the agent: it is all the agent knows about it. The agent calls a method by its name in snake_case, here `set_quantity`.
- Types of parameters, results and getters: `String`, `bool`, `int`, `double`, `num`, `DateTime`, enums, extension types over a scalar, `List<T>` and plain classes. Maps, sets, records and generic classes fail the build: list a thin method that takes supported types instead. See [the rules](https://github.com/leancodepl/tandem/blob/main/packages/tandem_generator/README.md#supported-types).
- Reject the agent's bad input with a `ToolCallRefused`, before the method changes any state: the agent gets its message and tries again. Its message goes to the agent: put nothing in it the agent must not see. Any other exception, an `ArgumentError` too, is a bug: Tandem reports it and tells the agent the call failed and may have changed the app.
- After an `await`, check `isClosed` before `emit` (`ref.mounted` before `state =` in a `Notifier`): the screen may have closed meanwhile.

**Done when** every `.sees` is a getter and every `.calls` a method of this class, each has a doc comment, `changes` reports every change (for a Cubit, `stream`), every `.sees` stands directly in the list, not inside an `if`, a `for`, a `?:` or a spread, and everything a `.callsWithApproval` method depends on is listed with `.sees`.

## 3. Generate the code

```sh
dart run build_runner build
```

Run it again after every change to the list, to a listed method's signature or to its doc comment. In CI, run `dart run build_runner build && git diff --exit-code`. An outdated `.g.dart` is not always caught at runtime, for example when two parameters of the same type swap places.

**Done when** `order_cubit.g.dart` exists and `dart analyze --fatal-infos` is clean. A failed build names what to fix and where.

## 4. Build the chat

Tandem has no chat widget. Write one in the app's design system, with every text in the app's localization. If the app already has a chat, give it this session. A screen that needs no chat can have a button that calls `session.send` and shows `session.status` instead, as in [Fill from e-mail](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#fill-from-e-mail), and skip the rest of this step.

```dart
final class const AgentChat() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    // The items of session.items, then the field and its button.
  }
}
```

- `TandemSessionScope.of(context)` gives the session and rebuilds the widget when it changes.
- Show every item of `session.items`, oldest first, with a `switch` over `ChatItem`: `UserMessage` and `AgentMessage` by their `text`, an `AgentMessage` with `stopped` marked as stopped, a `ChatNotice` by its `kind`, an `ApprovalRequest` as a card.
- A card whose `request.status` is `pending` has Approve and Reject, which call `session.approve(request)` and `session.reject(request)`. Both throw an `ApprovalNotPending` when the request changed as the user tapped, such as when what the agent sees changed: catch it, the card then shows the new `request.status`. Every other `request.status` gets a line: `approved`, `rejected`, `invalidated` (what the agent sees changed, so the user asks the agent again) and `cancelled`.
- `request.description` and `request.arguments` are written for the agent. Show the user what the method will do in the app's words, chosen by `request.tool`.
- The field calls `session.send(text)`. Its button switches on the sealed `session.status`: Send for `Idle()` and `AwaitingApproval()`, Stop that calls `session.stop()` for `Thinking()` and `Calling(approved: false)`, a disabled Stop for `Calling(approved: true)` (an approved method runs to its end) and a disabled "Stopping" for `Stopping()`.
- `session.startOver()` sends the next message to a new thread without the earlier history, such as after a `RunFailed` whose `code` says the history no longer fits. It does nothing while a run is open. Give the `startedOver` notice a line too.
- [`example/lib/agent_chat.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the Tandem repository does all of this in one file. Copy its structure, not its texts.

**Done when** the switches over `ChatItem` and `session.status` have no `_` case and every text of the chat comes from the app's localization.

## 5. Wrap the screen

```dart
BlocProvider(
  create: (_) => OrderCubit(catalog: catalog, orders: orders),
  child: TandemScope(
    surface: (context) => context.read<OrderCubit>(),
    agent: Uri.parse('http://localhost:8000/agent'),
    approvals: const .fromState(),
    child: const Row(
      children: [
        Expanded(child: OrderForm()),
        SizedBox(width: 360, child: AgentChat()),
      ],
    ),
  ),
)
```

`TandemScope` goes below whatever owns the state object, such as the `BlocProvider` of the Cubit, and the screen and its chat below the scope. `surface` reads the object when the scope opens its session. With provider it is `context.read<TodoList>()` below the `ChangeNotifierProvider`. With Riverpod, the screen is a `ConsumerWidget`, a widget below the scope watches the provider to keep it alive, and `surface` is `(context) => ref.read(cartProvider.notifier)`. `onEvent: (context, event, session) { ... }` hears what happens in the session: an `AgentCall` for every listed method that returned (`tool`, `arguments`, `result`), `RunStopped`, `RunFailed` and `ConnectionLost`. `surface` and `onEvent` get the scope's context, below the `BlocProvider`, so `context.read<OrderCubit>()` works there.

`approvals` says how the user approves a call of a `.callsWithApproval` method:

- `.fromState()` when the chat of step 4 draws the requests as cards.
- `.callback((context, request, session) async { ... })` for a dialog or a bottom sheet. Tandem calls it for each request when it shows. Decide with `session.approve(request)` or `session.reject(request)` and catch `ApprovalNotPending`. [An approval dialog](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#an-approval-dialog) is a screen to copy.
- `.none()` only for a screen without `.callsWithApproval`.

Any AG-UI endpoint works. The backend must put the AG-UI `context` into the model's prompt (ag-ui-adk does not, so add an instruction provider) and accept `tools` on every run. On the web it needs CORS for the app's origin. A sandboxed macOS app needs the `com.apple.security.network.client` entitlement. [`example/agent`](https://github.com/leancodepl/tandem/tree/main/example/agent) in the Tandem repository is a working Google ADK backend to copy from. For a backend that needs the user's token, pass `HttpAgentConnection(uri, client: ...)` with an `http.Client` that adds it to `TandemScope.connected`, and keep the connection in a field ([example](https://github.com/leancodepl/tandem/blob/main/doc/examples.md#a-token-for-your-backend)).

**Done when** the app shows the chat next to the screen, or the button on it, and a screen with `.callsWithApproval` has `.fromState()` with a chat that draws the cards, or `.callback`. Step 6 checks the rest without a backend.

## 6. Test it with a script

`ScriptedAgent` plays a script instead of a model, so the test needs no network:

```dart
import 'package:tandem/testing.dart';

testWidgets('the agent sets a quantity', (tester) async {
  final cubit = OrderCubit(catalog: catalog, orders: orders);
  final agent = ScriptedAgent([
    (_) => [AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 15})],
    (_) => [AgentStep.say('Done.')],
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

Every turn of the script is one run: the first calls the tool, the second comes after Tandem sent the answer. `agent.requests` holds every body sent, so a test can check what the agent saw in `context`. `find.text('Send')` stands for the chat's send button. To approve a call, tap the card's Approve. To check only what the Cubit gives the agent, use `AgentListing.of(cubit)`, with its `context`, `tools` and `call(name, arguments)`.

**Done when** the test passes and shows the state the method changed.

## Mistakes

- `.sees` inside an `if`, a `for`, a `?:` or a spread. The build fails. Keep it listed and let the getter return an empty value.
- A change to the list or a signature without running build_runner again. It shows as a `StateError` that says to run it.
- `TandemScope` above the provider of the state object, or a chat with no `TandemScope` above it.
- `changes` from a plain `StreamController`. The next session cannot listen to it: use `StreamController.broadcast()`.
- `riverpod_generator` on a class with `@TandemAgent()`. Both write `_$Name` into the same `.g.dart`, and it does not compile. Write the provider by hand.
- A `.sees` value that changes on its own, for example on a timer. Every change invalidates an open card for good.
- A `.callsWithApproval` method that depends on state not listed with `.sees`. A change to that state leaves the card pending, and the method runs on a state the agent never saw.
- `approvals: .none()` on a screen with `.callsWithApproval`. Every such call is refused.
- A `ScriptedAgent` made in `build`. A new connection starts a new session, so keep it in a field.
