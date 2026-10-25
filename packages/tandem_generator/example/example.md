A Cubit with `@TandemAgent()` lists what the agent sees and calls. It is the order form of the [README of tandem](https://github.com/leancodepl/tandem#quick-start):

<!-- example/lib/order_cubit.dart -->

```dart
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

`dart run build_runner build` writes the `_$OrderCubit` mixin into `order_cubit.g.dart`. Its `agentSchema` gives each `.sees` its name, doc comment and JSON:

<!-- example/lib/order_cubit.g.dart -->

```dart
        AgentView.of(
          () => surface.draft,
          'draft',
          'The order as the user sees it on the screen.',
          (draft) => {
            'lines': [
              for (final item in draft.lines)
                {'sku': item.sku, 'quantity': item.quantity},
            ],
          },
        ),
```

And each method its name in snake_case, doc comment, JSON Schema and a call with the agent's arguments:

<!-- example/lib/order_cubit.g.dart -->

```dart
        AgentTool(
          surface.setQuantity,
          name: 'set_quantity',
          description: 'Sets how many pieces of [sku] the order has.',
          parameters: const {
            'type': 'object',
            'properties': {
              'sku': {'type': 'string'},
              'quantity': {'type': 'integer'},
            },
            'required': ['sku', 'quantity'],
          },
          invoke: (args) {
            surface.setQuantity(args.read('sku'), args.read('quantity'));
            return null;
          },
        ),
```

How an app uses it, from the scope to the chat: the [example of tandem](https://pub.dev/packages/tandem/example) and its [README](https://pub.dev/packages/tandem).
