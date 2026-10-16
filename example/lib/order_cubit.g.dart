// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$OrderCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final cubit = this as OrderCubit;
    return AgentSchema(
      sees: [
        AgentView.of(
          () => cubit.draft,
          'draft',
          'The order as the user sees it on the screen.',
          (draft) => {
            'lines': [
              for (final item in draft.lines)
                {'sku': item.sku, 'quantity': item.quantity},
            ],
          },
        ),
      ],
      calls: [
        AgentTool(
          cubit.searchCatalog,
          name: 'search_catalog',
          description: 'Finds products by name or description.',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
          invoke: (args) async {
            final result = await cubit.searchCatalog(args.read('query'));
            return [
              for (final item in result)
                {
                  'sku': item.sku,
                  'name': item.name,
                  'description': item.description,
                },
            ];
          },
        ),
        AgentTool(
          cubit.setQuantity,
          name: 'set_quantity',
          description: 'Sets how many pieces of [sku] the order has.',
          parameters: {
            'type': 'object',
            'properties': {
              'sku': {'type': 'string'},
              'quantity': {'type': 'integer'},
            },
            'required': ['sku', 'quantity'],
          },
          invoke: (args) {
            cubit.setQuantity(args.read('sku'), args.read('quantity'));
            return null;
          },
        ),
        AgentTool(
          cubit.placeOrder,
          name: 'place_order',
          description: 'Places the order exactly as it is on the screen.',
          parameters: {'type': 'object', 'properties': {}},
          invoke: (args) => cubit.placeOrder(),
        ),
      ],
    );
  }
}
