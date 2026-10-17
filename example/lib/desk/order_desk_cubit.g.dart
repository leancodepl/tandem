// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_desk_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$OrderDeskCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as OrderDeskCubit;
    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.order,
          'order',
          'The order as the user sees it on the screen.',
          (order) => {
            'customer': switch (order.customer) {
              null => null,
              final customer => {
                'id': customer.id,
                'name': customer.name,
                'contact': customer.contact,
                'priceList': customer.priceList,
              },
            },
            'lines': [
              for (final item in order.lines)
                {
                  'sku': item.sku,
                  'name': item.name,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'discount': item.discount,
                  'lineTotal': item.lineTotal,
                },
            ],
            'delivery': switch (order.delivery) {
              null => null,
              final delivery => {
                'address': delivery.address,
                'date': delivery.date.toIso8601String(),
              },
            },
            'total': order.total,
          },
        ),
      ],
      calls: [
        AgentTool(
          surface.searchCatalog,
          name: 'search_catalog',
          description: 'Finds products by SKU, name or description.',
          parameters: const {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
          invoke: (args) async {
            final result = await surface.searchCatalog(args.read('query'));
            return [
              for (final item in result)
                {
                  'sku': item.sku,
                  'name': item.name,
                  'description': item.description,
                  'price': item.price,
                },
            ];
          },
        ),
        AgentTool(
          surface.setCustomer,
          name: 'set_customer',
          description: 'Sets the customer the order is for; prices follow their price list.',
          parameters: const {
            'type': 'object',
            'properties': {
              'customerId': {'type': 'string'},
            },
            'required': ['customerId'],
          },
          invoke: (args) {
            surface.setCustomer(args.read('customerId'));
            return null;
          },
        ),
        AgentTool(
          surface.setQuantity,
          name: 'set_quantity',
          description: 'Sets how many pieces of [sku] the order has; 0 removes the line.',
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
        AgentTool(
          surface.setDelivery,
          name: 'set_delivery',
          description: 'Sets where and when the order is delivered.',
          parameters: const {
            'type': 'object',
            'properties': {
              'address': {'type': 'string'},
              'date': {'type': 'string', 'format': 'date-time'},
            },
            'required': ['address', 'date'],
          },
          invoke: (args) {
            surface.setDelivery(args.read('address'), args.read('date'));
            return null;
          },
        ),
        AgentTool(
          surface.placeOrder,
          name: 'place_order',
          description: 'Places the order exactly as it is on the screen.',
          parameters: const {'type': 'object', 'properties': {}},
          invoke: (args) => surface.placeOrder(),
        ),
      ],
    );
  }
}
