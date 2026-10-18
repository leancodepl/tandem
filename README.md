# tandem

<p align="center">
  <img src="https://github.com/leancodepl/tandem/raw/main/doc/imgs/logo.png" alt="A robot and Dash riding a tandem bike" width="400">
  <br>
  <a href="https://pub.dev/packages/leancode_lint"><img src="https://img.shields.io/badge/style-leancode__lint-f0ff00?style=for-the-badge" alt="style: leancode_lint"></a>
</p>

Let an AI agent work on an existing Flutter screen together with the user. The agent sees what you let it see, calls the same methods your buttons call, and anything that matters waits for the user's approval.

Tandem speaks [AG-UI](https://docs.ag-ui.com), so the agent can run on any AG-UI backend.

## Quick start

Requires Dart 3.13 (Flutter 3.47) or newer.

1. Add the packages:

   ```sh
   flutter pub add tandem
   flutter pub add dev:build_runner dev:tandem_generator
   ```

2. List what the agent may see and call:

   ```dart
   part 'order_cubit.g.dart';

   @TandemAgent()
   class OrderCubit({required final Catalog catalog, required final Orders orders})
       extends Cubit<OrderState>
       with _$OrderCubit {
     this : super(.new(draft: .empty));

     @override
     List<AgentCapability> get agentCapabilities => [
       .sees(draft),
       .calls(searchCatalog),
       .calls(setQuantity),
       if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
     ];

     @override
     Stream<Object?> get changes => stream;

     /// The order as the user sees it on the screen.
     OrderDraft get draft => state.draft;

     /// Finds products by name or description.
     Future<List<Product>> searchCatalog(String query) => catalog.search(query);

     /// Sets how many pieces of [sku] the order has.
     void setQuantity(String sku, int quantity) { ... }

     /// Places the order exactly as it is on the screen.
     Future<OrderId> placeOrder() async { ... }
   }
   ```

   The agent gets exactly what is on the list. It reads the doc comments, and the parameter types become the schema. The list is read again before every turn, so it can depend on the state or on who the user is. `changes` reports every change of the state, for a Cubit its `stream`.

3. Generate the code:

   ```sh
   dart run build_runner build
   ```

   Every class with `@TandemAgent()` gets a `_$Name` mixin, here `_$OrderCubit`. Each `.sees` must stand directly in the list after `get agentCapabilities =>`, not inside an `if`, a `for`, a `?:` or a spread, or the build fails.

   In CI, run `dart run build_runner build && git diff --exit-code`. An outdated `.g.dart` is not always caught at runtime, for example when two parameters of the same type swap places.

4. Wrap the screen and its chat:

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

   The scope reads the Cubit with `surface` when it opens its session, and keeps that session until it leaves the tree or gets another `agent`. `approvals` says how the user approves a call: here the chat draws the requests. See [Approvals](#approvals) for a dialog.

5. Build the chat. Tandem has no chat widget, so the chat has your app's texts, language and look. `TandemSessionScope.of(context)` gives the session and rebuilds the widget when it changes:

   ```dart
   final session = TandemSessionScope.of(context);

   return ListView(
     children: [
       for (final item in session.items)
         switch (item) {
           UserMessage(:final text) => ...,
           AgentMessage(:final text, :final stopped) => ...,
           ChatNotice(:final kind) => ...,
           final ApprovalRequest request => ...,
         },
     ],
   );
   ```

   `ChatItem` is sealed, so the compiler checks that the switch covers every kind. The field calls `session.send(text)`. Its button switches on `session.status`, also sealed: Send while `Idle` or `AwaitingApproval`, Stop while `Thinking` or `Calling` a method the user did not approve, and disabled while an approved method runs to its end or a stopped run is `Stopping`. A card whose `request.status` is `pending` has Approve and Reject, which call `session.approve(request)` and `session.reject(request)`. The card's `description` is the method's doc comment, written for the agent, so a localized card picks its own text by `request.tool`.

   [`AgentChat`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the example does all of this in one file, ready to copy.

The agent changes the screen through the same methods as your buttons, so the same validation runs for both. When the user edits something, the agent sees it on its next turn.

> [!TIP]
> Setting this up with a coding agent? `dart run skills@ get` installs Tandem's skill from your dependencies, and the agent follows these steps.

## Approvals

A method listed with `.callsWithApproval` runs only after the user approves it, which calls `session.approve`. The approval covers what the agent sees when it asks, so list everything the method depends on with `.sees`. Tandem compares `.sees` with what the agent saw when its turn ends, on every event of `changes` and on Approve. When they differ, the card is invalidated for good, or does not show at all, and the agent has to ask again. A change undone before Tandem checks, such as A, B, A in one go, leaves the card pending, and so does a change outside `.sees`, such as a selected tab or a loading flag.

`approvals:` on the scope says how the screen asks:

- `.fromState()`: the UI draws the requests itself, from `session.items` like the chat above, or from the status `AwaitingApproval(request)`.
- `.callback((context, request, session) async { ... })`: Tandem calls it for each request when it shows, for a dialog, a bottom sheet or anything imperative. `context` is the scope's, and the callback decides with `session.approve` or `session.reject`. A request it leaves undecided stays pending until the user's next message cancels it.
- `.none()`: the screen never asks. A call that needs approval is refused to the agent and reported in debug.

A dialog to copy, where `approvalTitle` stands for your app's text for `request.tool`:

```dart
approvals: .callback((context, request, session) async {
  final labels = MaterialLocalizations.of(context);
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(approvalTitle(context, request)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(labels.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(labels.okButtonLabel),
        ),
      ],
    ),
  );
  try {
    if (approved ?? false) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // Invalidated or cancelled while the dialog showed.
  }
}),
```

When the agent asks for several approvals in one turn, Tandem asks for them one at a time, in order: the next one shows once the previous one is decided and its method returned. Each keeps what the agent saw when it asked, so an approved method that changes `.sees` invalidates the rest. Reject tells the agent the user said no and cancels the rest, so the agent plans again. Sending a message while a card is open cancels the card.

`approve` and `reject` either decide or throw. The same decision twice does nothing, so a double tap is harmless. A decision that cannot happen, such as approving an invalidated request, throws an `ApprovalNotPending`. `session.isPending(request)` tells whether a request still waits. Stop finishes reading the agent's turn but runs nothing more from it. An approved method runs to its end, so Stop is unavailable until it returns.

## Events

`onEvent` on the scope hears what happens in the session, as a sealed `TandemEvent`: `AgentCall` after a listed method returned, with its `tool`, `arguments` and `result`, then `RunStopped`, `RunFailed` and `ConnectionLost`. `RunFailed` and `ConnectionLost` also add a `ChatNotice` to `session.items`, and a stop adds one or marks the last message `stopped`. It gets the scope's context, below the `BlocProvider`, and the session:

```dart
onEvent: (context, event, session) {
  if (event case AgentCall(tool: 'place_order', :final result)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Placed order $result')),
    );
  }
},
```

## The agent

Any AG-UI endpoint works. The backend has to:

- Put the AG-UI `context` into the model's prompt. ag-ui-adk does not, so its agent needs an instruction provider that adds it.
- Accept `tools` on every run. Tandem always sends it, an empty list when no method is listed.
- On the web, allow the app's origin with CORS.

A sandboxed macOS app needs the `com.apple.security.network.client` entitlement to reach the agent.

The [example](https://github.com/leancodepl/tandem/tree/main/example) is an order desk app with a Google ADK agent in Python. Its README says how to run both.

## Testing

`ScriptedAgent` plays a fixed script instead of a model, so widget tests run without network. `TandemScope.connected` takes it in place of the endpoint:

```dart
import 'package:tandem/testing.dart';

final agent = ScriptedAgent([
  (_) => [AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 15})],
  (_) => [AgentStep.say('Done.')],
]);

await tester.pumpWidget(
  MaterialApp(
    home: BlocProvider(
      create: (_) => OrderCubit(catalog: catalog, orders: orders),
      child: TandemScope.connected(
        surface: (context) => context.read<OrderCubit>(),
        connection: agent,
        approvals: const .fromState(),
        child: const Row(
          children: [
            Expanded(child: OrderForm()),
            SizedBox(width: 360, child: AgentChat()),
          ],
        ),
      ),
    ),
  ),
);
```

## Status

Experimental. The API can change before 1.0. Not supported yet: AG-UI interrupts, Riverpod.

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
