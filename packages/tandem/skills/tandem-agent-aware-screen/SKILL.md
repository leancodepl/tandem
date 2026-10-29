---
name: tandem-agent-aware-screen
description: Make a Flutter screen agent-aware with Tandem, so an agent sees what the screen shows, calls the methods of its state class (a Cubit, a Riverpod Notifier or a ChangeNotifier), and anything that matters waits for the user's approval. Use when asked to add Tandem or an AI agent to a Flutter screen, or when the code uses TandemScope, @TandemAgent or agentCapabilities.
user-invocable: false
---

# Make a screen agent-aware with Tandem

This is the base for both kinds of agent. A coding agent drives the screen in a debug build (skill `tandem-coding-agent`), and an in-app agent works with the app's users (skill `tandem-in-app-agent`). This skill adds neither a chat nor a backend: they belong to `tandem-in-app-agent`, and only when the user chose it.

Tandem works on a screen that already has a state class: a Cubit, a Riverpod `Notifier`, a `ChangeNotifier`, or any class that can report its changes. The agent sees what the class lists with `.sees` and acts only through the methods it lists, the same ones the screen's widgets call. When the screen keeps its state in a `State` with `setState`, ask the user before you move it into a `ChangeNotifier`. The steps use a Cubit and say where provider and Riverpod differ. Do the steps in order and check each "Done when" before the next.

## 1. Add the packages

`tandem` goes in `dependencies`, `tandem_generator` and `build_runner` in `dev_dependencies`. Add what `pubspec.yaml` lacks:

```sh
flutter pub add tandem
flutter pub add dev:build_runner dev:tandem_generator
```

Keep `tandem` and `tandem_generator` on the same minor version. Needs Dart 3.13 (Flutter 3.47) or newer. In a project with `.fvmrc`, run every command through `fvm`.

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
- `.calls(method)`: a method of this class that a widget already calls, such as a field's setter, so the same validation runs for both.
- `.callsWithApproval(method)`: anything the user cannot easily undo, that costs money or that sends something. It runs only after the user approves it in the app. The approval covers only what is listed with `.sees`, so list everything the method depends on. A change to those values after the agent asked invalidates the request.
- A value the agent must not see, such as a password, a PIN or a national ID number, stays out of `.sees` and out of every listed method. The user types it. When a `.callsWithApproval` method depends on such a value, the approval cannot cover it: leave the method out, or list a count of the value's edits with `.sees`, so that an edit invalidates the request.
- The list is read again before every turn and every call, so an `if` can hide a method.
- `changes` reports every change of the class as a broadcast stream. A Cubit returns its `stream`. A Riverpod `Notifier` adds each state to a `StreamController.broadcast()` from `listenSelf` in `build`, and never closes it in `ref.onDispose`, which Riverpod calls before every rebuild. A `ChangeNotifier` adds to one in an override of `notifyListeners`. With `riverpod_lint`, mark a `Notifier`'s getter for `.sees` `@protected`: `avoid_public_notifier_properties` skips it.
- Every listed getter and method needs a doc comment written for the agent: it is all the agent knows about it. Say the format and the range of a value, such as "a date from tomorrow on" or "empty for none". The agent calls a method by its name in snake_case, here `set_quantity`. A listed getter's name is in snake_case too, but parameters and the fields of a plain class keep their Dart names, such as `deliveryDate`: write them so in doc comments.
- Types of parameters, results and getters: `String`, `bool`, `int`, `double`, `num`, `DateTime`, `Uri`, enums, token classes (values that are their own `static const` members), extension types over a scalar, `List<T>`, `Set<T>` and classes with a public constructor and a getter per parameter, generic ones too. Maps, records and sealed classes fail the build: list a thin method that takes supported types instead. See [the rules](https://github.com/leancodepl/tandem/blob/main/packages/tandem_generator/README.md#supported-types).
- Reject the agent's bad input with a `ToolCallRefused`, before the method changes any state: the agent gets its message and tries again. Its message goes to the agent: put nothing in it the agent must not see. Any other exception, an `ArgumentError` too, is a bug: Tandem reports it and tells the agent the call failed and may have changed the app.
- After an `await`, check that the object is still alive before you change it: `isClosed` in a Cubit, `ref.mounted` in a `Notifier`, a flag that `dispose` sets in a `ChangeNotifier`.

**Done when** every `.sees` is a getter and every `.calls` a method of this class, each has a doc comment, `changes` reports every change, every `.sees` stands directly in the list, not inside an `if`, a `for`, a `?:` or a spread, and everything a `.callsWithApproval` method depends on is listed with `.sees`.

## 3. Generate the code

```sh
dart run build_runner build
```

Run it again after every change to the list, to a listed method's signature or to its doc comment. In CI, run `dart run build_runner build && git diff --exit-code`. An outdated `.g.dart` is not always caught at runtime, for example when two parameters of the same type swap places.

**Done when** `order_cubit.g.dart` exists and `dart analyze --fatal-infos` is clean. A failed build names what to fix and where.

## 4. Show the agent's changes

The agent changes the state through the listed methods, not through the widgets, so every widget has to show the state as it is now. A `TextField` with its own `TextEditingController` keeps its old text, and so does a `DropdownButtonFormField` with `initialValue`. Copy the new value into the controller when the state changes, such as in `didUpdateWidget` or a `BlocListener`, or key the dropdown with its value.

**Done when** every field of the screen reads its value from the state class when the state changes.

## 5. Wrap the screen

```dart
BlocProvider(
  create: (context) => OrderCubit(orders: context.read<Orders>()),
  child: TandemScope(
    surface: (context) => context.read<OrderCubit>(),
    approvals: const .callback(confirmOrder),
    child: const OrderForm(),
  ),
)
```

`TandemScope` goes below whatever owns the state object, such as the `BlocProvider` of the Cubit, and the screen below the scope. `surface` reads the object when the scope opens its session. With provider it is `context.read<TodoList>()` below the `ChangeNotifierProvider`. With Riverpod, the screen is a `ConsumerWidget`, a widget below the scope watches the provider to keep it alive, and `surface` is `(context) => ref.read(cartProvider.notifier)`.

The scope has no `agent:` here: a coding agent needs none. `tandem-in-app-agent` adds it, with a chat, when the user wants an in-app agent.

`approvals` says how the user approves a call of a `.callsWithApproval` method:

- `.callback(confirmOrder)` shows a dialog, as in step 6.
- `.none()` only for a screen without `.callsWithApproval`. Every such call is refused.
- `.fromState()` only when the screen draws `session.items` or the status `AwaitingApproval` itself, such as a chat with approval cards.

**Done when** the app builds and the screen looks as before.

## 6. Ask for approval

Skip this step when the class lists no `.callsWithApproval`. Otherwise the callback shows what the method will do, in the app's words, and decides:

```dart
Future<void> confirmOrder(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final draft = context.read<OrderCubit>().draft;
  final place = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Place this order?'),
      content: Text('${draft.lines.length} products'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Place order'),
        ),
      ],
    ),
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

- Tandem calls it for each request when it shows, with the scope's context, so `context.read<OrderCubit>()` works.
- `request.tool` names the method. `request.description` and `request.arguments` are written for the agent: show the user what the screen shows, in the app's words.
- Write the texts as the rest of the app does: from its localization when it has one, inline when it has none.
- `approve` and `reject` throw `ApprovalNotPending` when the request changed meanwhile: catch it.

**Done when** every `.callsWithApproval` method of the class has a way to be approved: this callback, or a UI that draws the requests with `.fromState()`.

## 7. Test it

`TandemBridge.call` calls a listed method as an agent would and answers with JSON, so a widget test needs no agent and no network. Pump the screen as the app builds it, with what it reads from above:

```dart
testWidgets('an agent fills the order screen', (tester) async {
  await tester.pumpWidget(
    RepositoryProvider.value(
      value: Orders(),
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

- `answer['status']` is `returned` with the method's `result`, or `refused` with a `reason`, such as for arguments that do not fit the schema. Its `screens` show what the agent sees after the call.
- `TandemBridge.describe()` gives what the agent sees and may call, without calling anything.
- Test what the screen decides: a `ToolCallRefused`, a method hidden by an `if`, a field that shows the agent's value.

**Done when** the test passes and the screen shows the value the agent set.

## Mistakes

- `.sees` inside an `if`, a `for`, a `?:` or a spread. The build fails. Keep it listed and let the getter return an empty value.
- A change to the list or a signature without running build_runner again. It shows as a `StateError` that says to run it.
- `TandemScope` above the provider of the state object.
- `changes` from a plain `StreamController`. The next session cannot listen to it: use `StreamController.broadcast()`.
- `riverpod_generator` on a class with `@TandemAgent()`. Both write `_$Name` into the same `.g.dart`, and it does not compile. Write the provider by hand.
- A `.sees` value that changes on its own, for example on a timer. Every change invalidates a waiting request.
- A `.callsWithApproval` method that depends on state not listed with `.sees`. A change to that state leaves the request pending, and the method runs on a state the agent never saw.
- `approvals: .fromState()` on a screen that draws no requests. A request waits where nobody sees it.
- A class of the app named like one that `package:tandem/tandem.dart` exports, such as `Idle`. Import Tandem with `show` or `hide`.
