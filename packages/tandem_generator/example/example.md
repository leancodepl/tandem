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

`dart run build_runner build` writes the `_$OrderCubit` mixin into `order_cubit.g.dart`. Its `agentSchema` gives each `.sees` its name, its doc comment and a description of its type, from which Tandem writes the value as JSON:

<!-- example/lib/order_cubit.g.dart -->

```dart
        AgentView.of(() => surface.draft).as(
          'draft',
          'The order as the user sees it on the screen.',
          .object(
            id: 'package:example/order.dart#OrderDraft',
            fields: (field) => [
              field('lines', (value) => value.lines).as(
                .list(
                  .object(
                    id: 'package:example/order.dart#OrderLine',
                    description:
                        'One product of an order and how many pieces of it.',
                    fields: (field) => [
                      field(
                        'sku',
                        (value) => value.sku,
                        description: "The product's code in the catalog.",
                      ).as(.string),
                      field(
                        'quantity',
                        (value) => value.quantity,
                        description: 'How many pieces.',
                      ).as(.integer),
                    ],
                    build: (values) =>
                        .new(sku: values('sku'), quantity: values('quantity')),
                  ),
                ),
              ),
            ],
            build: (values) => .new(lines: values('lines')),
          ),
        ),
```

And each method its name in snake_case, its doc comment, its parameters, and a call with the agent's arguments read as their types:

<!-- example/lib/order_cubit.g.dart -->

```dart
        AgentTool(
          surface.setQuantity,
          name: 'set_quantity',
          description: 'Sets how many pieces of [sku] the order has.',
          parameters: [
            const AgentParameter<String>('sku', .string),
            const AgentParameter<int>('quantity', .integer),
          ],
          invoke: (args) {
            surface.setQuantity(args.read('sku'), args.read('quantity'));
            return null;
          },
        ),
```

How an app uses it, from the scope to the chat: the [example of tandem](https://pub.dev/packages/tandem/example) and its [README](https://pub.dev/packages/tandem).
