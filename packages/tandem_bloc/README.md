# tandem_bloc

[![tandem_bloc pub.dev badge][pub-badge]][pub-badge-link]
[![Test status][test-badge]][test-badge-link]
[![License: Apache 2.0][license-badge]][license-badge-link]
[![style: leancode_lint][leancode-lint-badge]][leancode-lint-badge-link]

Connects [Tandem][tandem] to [bloc][bloc]. The screen's existing `Cubit` or
`Bloc` holds the shared state, so the agent and the user work on the same
state, and a `TandemScope` makes the screen below it agent-aware.

## Installation

```sh
flutter pub add tandem tandem_bloc
```

## Usage

Provide the connection to the agent backend once, for the whole app:

```dart
RepositoryProvider<AgentConnection>(
  create: (context) =>
      AgentConnection.http(Uri.parse('https://example.com/agent')),
  child: const MyApp(),
)
```

Keep the type argument. `RepositoryProvider.value(value: ScriptedAgent(...))`
provides a `ScriptedAgent`, and `TandemScope` does not find it.

Make the screen's cubit the state host. It gains one `with` clause, and its
methods stay as they are:

```dart
class OrderCubit extends Cubit<OrderState> with AgentEditable<OrderState> {
  // existing methods unchanged
}
```

Put a `TandemScope` under the cubit's `BlocProvider`. The codec says which
part of the state the agent sees, and the tools are the functions of the app
the agent may call:

```dart
BlocProvider(
  create: (context) => OrderCubit(),
  child: TandemScope<OrderCubit, OrderState>(
    codec: StateCodec.lens(
      'order',
      get: (state) => state.draft,
      set: (state, draft) => state.copyWith(draft: draft),
      fromJson: OrderDraft.fromJson,
      toJson: (draft) => draft.toJson(),
    ),
    tools: (context) => [
      Tool(
        'search_catalog',
        'Find products matching free text from the e-mail.',
        params: {'query': const Param.string('For example "HDMI cable 2m"')},
        run: (call) => context.read<Catalog>().search(call.read('query')),
      ),
      Tool(
        'place_order',
        'Place the order exactly as it is on the screen.',
        needsApproval: true,
        run: (call) => context.read<Orders>().place(call.state.draft),
      ),
    ],
    child: const OrderScreen(),
  ),
)
```

On the screen, `context.watch<TandemCubit>().state` is a `TandemView`: the
timeline (user and agent messages, tool activity, approval requests), whether
the agent is running, the last error and the agent marks.

```dart
final view = context.watch<TandemCubit>().state;

// Send what the user typed.
context.read<TandemCubit>().send(text);

// Highlight a field the agent filled in.
final byAgent = view.marks.has('lines/1/quantity');

// An approval card needs nothing but the request.
FilledButton(
  onPressed: request.canApprove ? request.approve : null,
  child: const Text('Place order'),
)
```

## Good to know

- The agent's changes are emitted into the cubit directly. They skip the
  cubit's methods and, on a `Bloc`, its event handlers. To limit what the
  agent may write, check it where the codec builds the state, such as in the
  `set` of `StateCodec.lens`.
- A field shows the agent's changes only when it is built from the state. A
  `TextField` with only an `initialValue`, or a controller that is never
  updated, keeps showing the old value.
- `TandemScope` reads everything it needs once, when it is first built: the
  codec, the tools, the options, the connection and the cubit. Give it a new
  `key` to start a new session.
- When the route closes, the session is disposed before the cubit is closed,
  so the agent never writes into a closed cubit. A tool that is still
  running finishes; if it changes a cubit afterwards, it should check the
  cubit's `isClosed` first.

## Testing

`package:tandem/testing.dart` has a `ScriptedAgent`: an `AgentConnection`
that plays a script instead of calling an agent backend, with no network and
no API key. By default it behaves like ag-ui-adk and rejects requests that
break the AG-UI rules.

```dart
testWidgets('the agent fills in the customer', (tester) async {
  final agent = ScriptedAgent([
    (request) => const [
      AgentStep.patchState([
        {'op': 'replace', 'path': '/order/customer', 'value': 'Acme'},
      ]),
      AgentStep.say('Acme it is.'),
    ],
  ]);
  await tester.pumpWidget(
    RepositoryProvider<AgentConnection>.value(
      value: agent,
      child: const MaterialApp(home: OrderPage()),
    ),
  );

  await tester.enterText(find.byKey(const Key('message')), 'For Acme');
  await tester.tap(find.byKey(const Key('send')));
  await tester.pumpAndSettle();

  expect(find.text('Acme it is.'), findsOneWidget);
  expect(agent.isExhausted, isTrue);
});
```

Inside a turn, `expect` on the request works when a tester call, such as
`tester.tap`, started the run. When the test body starts the run itself, for
example with `cubit.send(...)` followed by `tester.pumpAndSettle()`, the
tester reports a guarded function conflict; check `agent.requests` after the
run instead.

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

Licensed under the [Apache License 2.0](https://github.com/leancodepl/tandem/blob/main/LICENSE).

[tandem]: https://pub.dev/packages/tandem
[bloc]: https://pub.dev/packages/flutter_bloc

[pub-badge]: https://img.shields.io/pub/v/tandem_bloc?style=for-the-badge&logo=dart
[pub-badge-link]: https://pub.dev/packages/tandem_bloc

[test-badge]: https://img.shields.io/github/actions/workflow/status/leancodepl/tandem/test.yml?branch=main&style=for-the-badge&logo=github
[test-badge-link]: https://github.com/leancodepl/tandem/actions/workflows/test.yml

[license-badge]: https://img.shields.io/github/license/leancodepl/tandem?style=for-the-badge
[license-badge-link]: https://github.com/leancodepl/tandem/blob/main/LICENSE

[leancode-lint-badge]: https://img.shields.io/badge/style-leancode__lint-f0ff00?style=for-the-badge
[leancode-lint-badge-link]: https://pub.dev/packages/leancode_lint

[leancode-landing]: https://leancode.co/?utm_source=github.com&utm_medium=referral&utm_campaign=tandem
[leancode-estimate]: https://leancode.co/get-estimate?utm_source=github.com&utm_medium=referral&utm_campaign=tandem
[leancode-packages]: https://pub.dev/packages?q=publisher%3Aleancode.co&sort=downloads
[patrol-landing]: https://patrol.leancode.co/?utm_source=github.com&utm_medium=referral&utm_campaign=tandem
