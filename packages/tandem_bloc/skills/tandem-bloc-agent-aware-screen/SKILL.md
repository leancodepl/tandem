---
name: tandem-bloc-agent-aware-screen
description: Make a Flutter screen agent-aware with Tandem (tandem_bloc), so an AI agent sees what the screen shows, calls the Cubit's methods, and anything that matters waits for the user's approval. Use when asked to add an AI agent, assistant or copilot to a Flutter screen, or when the code uses TandemScope, TandemChat, @TandemAgent or agentCapabilities.
---

# Make a screen agent-aware with Tandem

Tandem works on a screen that already has a Cubit. The agent sees what the Cubit lists with `.sees` and acts only through the methods it lists, the same ones the screen's buttons call. Do the steps in order and check each "Done when" before the next.

## 1. Add the packages

```sh
flutter pub add tandem_bloc
flutter pub add dev:build_runner dev:tandem_generator
```

Needs Dart 3.13 and Flutter 3.47.

**Done when** `flutter pub get` succeeds.

## 2. List what the agent may see and call

In the screen's Cubit:

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

  /// The order as the user sees it on the screen.
  OrderDraft get draft => state.draft;

  /// Sets how many pieces of [sku] the order has.
  void setQuantity(String sku, int quantity) { ... }

  /// Places the order exactly as it is on the screen.
  Future<OrderId> placeOrder() async { ... }
}
```

- `.sees(getter)`: a getter of this class, only what the user sees on the screen.
- `.calls(method)`: a method of this class that a button already calls, so the same validation runs for both.
- `.callsWithApproval(method)`: anything the user cannot easily undo, that costs money or sends something. It runs only after the user taps Approve.
- The list is read again before every turn and every call, so an `if` can hide a method.
- Every listed getter and method needs a doc comment, written for the agent: it is all the agent knows about it. The agent calls a method by its name in snake_case, here `set_quantity`.
- Types of parameters, results and getters: `String`, `bool`, `int`, `double`, `num`, `DateTime`, enums, extension types over a scalar, `List<T>` and plain classes. Maps, sets, records and generic classes fail the build: list a thin method that takes supported types instead. [The rules](https://github.com/leancodepl/tandem/blob/main/packages/tandem_generator/README.md#supported-types).
- Reject the agent's bad input with an `ArgumentError` (not a `RangeError`: it is an `ArgumentError`, but Tandem treats it as a bug, so `RangeError.range` does not work here): the agent gets its message and tries again. Any other exception is a bug, reported and answered as failed.
- After an `await`, check `isClosed` before `emit`: the screen may have closed meanwhile.

**Done when** every `.sees` is a getter and every `.calls` a method of this class, each has a doc comment, and every `.sees` stands directly in the list, not inside an `if`, a `for` or a spread.

## 3. Generate the code

```sh
dart run build_runner build
```

Run it again after every change to the list, to a listed method's signature or to its doc comment. In CI run `dart run build_runner build && git diff --exit-code`: an outdated `.g.dart` is not always caught at runtime, for example two parameters of the same type that swapped places.

**Done when** `order_cubit.g.dart` exists and `dart analyze --fatal-infos` is clean. A failed build names what to fix and where.

## 4. Wrap the screen

```dart
BlocProvider(
  create: (_) => OrderCubit(catalog: catalog, orders: orders),
  child: TandemScope<OrderCubit>(
    agent: Uri.parse('http://localhost:8000/agent'),
    child: const Row(
      children: [
        Expanded(child: OrderForm()),
        SizedBox(width: 360, child: TandemChat()),
      ],
    ),
  ),
)
```

`TandemScope` goes below the `BlocProvider` of the Cubit, `TandemChat` below the scope. `TandemChat` fills its parent, so give it the size you want. `onAgentCall: (context, call) { ... }` hears every listed method that ran (`call.tool`, `call.arguments`, `call.result`). Its context is below the `BlocProvider`, so `context.read<OrderCubit>()` works there.

The endpoint is any AG-UI endpoint. The backend must put the AG-UI `context` into the model's prompt (ag-ui-adk does not, so add an instruction provider) and accept `tools` on every run. On the web it needs CORS for the app's origin. A sandboxed macOS app needs the `com.apple.security.network.client` entitlement.

**Done when** the app shows the chat next to the screen. Step 5 checks the rest without a backend.

## 5. Test it with a script

`ScriptedAgent` plays a script instead of a model, so the test needs no network:

```dart
import 'package:tandem_bloc/testing.dart';

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
        child: TandemScope<OrderCubit>.connected(
          connection: agent,
          child: const TandemChat(),
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

Every turn of the script is one run: the first calls the tool, the second comes after Tandem sent the answer. `agent.requests` holds every body sent, so a test can check what the agent saw in `context`. To approve a call, tap `Approve` in the chat. To check only what the Cubit gives the agent, `AgentListing.of(cubit)` has `context`, `tools` and `call(name, arguments)`.

**Done when** the test passes and shows the state the method changed.

## Mistakes

- `.sees` inside an `if`, a `for` or a spread. The build fails. Keep it listed and let the getter return an empty value.
- A change to the list or a signature without running build_runner again. It shows as a `StateError` that says to run it.
- `TandemScope` above the `BlocProvider`, or `TandemChat` with no `TandemScope` above it.
- `TandemChat` in a `Row` without a width.
- A Cubit that emits on its own, for example on a timer. Every state it emits while a card is open invalidates the card for good.
- A `ScriptedAgent` made in `build`. A new connection starts a new session, so keep it in a field.
