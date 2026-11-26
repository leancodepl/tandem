// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$OrderCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as OrderCubit;

    return AgentSchema(
      sees: [
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
      ],
      calls: [
        AgentTool(
          surface.setQuantity,
          name: OrderCubitTool.setQuantity,
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
        AgentTool(
          surface.placeOrder,
          name: OrderCubitTool.placeOrder,
          description: 'Places the order exactly as it is on the screen.',
          parameters: [],
          invoke: (args) async {
            final result = await surface.placeOrder();

            return AgentResult(result).as(
              .extension(
                .string,
                (value) => .new(value),
                id: 'package:example/order.dart#OrderId',
              ),
            );
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

/// The names the agent knows the methods of [OrderCubit] by.
// `enum OrderCubitTool()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum OrderCubitTool implements ToolName {
  setQuantity,
  placeOrder;

  @override
  String get value => switch (this) {
    setQuantity => 'set_quantity',
    placeOrder => 'place_order',
  };

  @override
  String toString() => value;
}

extension on OrderCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('draft', draft),
    .calls(setQuantity),
    if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
  ];
}
