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
   flutter pub add tandem_bloc
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

   The agent gets exactly what is on the list. It reads the doc comments, and the parameter types become the schema. The list is read again before every turn, so it can depend on the state or on who the user is.

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
     child: TandemScope<OrderCubit>(
       agent: Uri.parse('http://localhost:8000/agent'),
       child: const Row(
         children: [
           Expanded(child: OrderForm()),
           SizedBox(width: 360, child: AgentChat()),
         ],
       ),
     ),
   )
   ```

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

   `ChatItem` is sealed, so the compiler checks that the switch covers every kind. The field calls `session.send(text)`. While `session.isRunning`, its button is Stop, which calls `session.stop()` only while `session.canStop`. `session.isStopping` stays true until the stopped run ends. A card whose `status` is `pending` has Approve and Reject, which call `session.approve(request)` and `session.reject(request)` and do nothing while `session.isRunning`. The card's `description` is the method's doc comment, written for the agent, so a localized card picks its own text by `request.tool`.

   [`AgentChat`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) in the example does all of this in one file, ready to copy.

The agent changes the screen through the same methods as your buttons, so the same validation runs for both. When the user edits something, the agent sees it on its next turn.

> [!TIP]
> Setting this up with a coding agent? `dart run skills@ get` installs Tandem's skill from your dependencies, and the agent follows these steps.

## Approvals

A method listed with `.callsWithApproval` runs only after the user approves it in the chat, which calls `session.approve`. The approval covers what the agent sees when it asks. If that changes, even back to what it was, the card is invalidated for good and the agent has to ask again.

Reject tells the agent the user said no. Sending a message while a card is open cancels the card. Stop finishes reading the agent's turn but runs nothing more from it. An approved method runs to its end, so Stop is unavailable until it returns.

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
import 'package:tandem_bloc/testing.dart';

final agent = ScriptedAgent([
  (_) => [AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 15})],
  (_) => [AgentStep.say('Done.')],
]);

await tester.pumpWidget(
  MaterialApp(
    home: BlocProvider(
      create: (_) => OrderCubit(catalog: catalog, orders: orders),
      child: TandemScope<OrderCubit>.connected(
        connection: agent,
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
