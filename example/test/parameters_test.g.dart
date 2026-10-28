// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parameters_test.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$EnumShelf implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as EnumShelf;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.sample,
          'sample',
          "The shelf's current and previous statuses.",
          (sample) => {
            'size': EnumName(sample.size).name,
            'status': EnumName(sample.status).name,
            'optionalStatus': switch (sample.optionalStatus) {
              null => null,
              final optionalStatus => EnumName(optionalStatus).name,
            },
            'statuses': [
              for (final item in sample.statuses) EnumName(item).name,
            ],
          },
        ),
      ],
      calls: [
        AgentTool(
          surface.echo,
          name: 'echo',
          description: 'Stores and returns [sample].',
          parameters: const {
            'type': 'object',
            'properties': {
              'sample': {
                'type': 'object',
                'properties': {
                  'size': {
                    'type': 'string',
                    'enum': ['s', 'm', 'l'],
                  },
                  'status': {
                    'type': 'string',
                    'enum': ['ready', 'sent'],
                  },
                  'optionalStatus': {
                    'anyOf': [
                      {
                        'type': 'string',
                        'enum': ['ready', 'sent'],
                      },
                      {'type': 'null'},
                    ],
                  },
                  'statuses': {
                    'type': 'array',
                    'items': {
                      'type': 'string',
                      'enum': ['ready', 'sent'],
                    },
                  },
                },
                'required': ['size', 'status', 'statuses'],
              },
            },
            'required': ['sample'],
          },
          invoke: (args) {
            final result = surface.echo(
              args.readObject(
                'sample',
                (sample) => .new(
                  size: sample.read('size', oneOf: [.s, .m, .l]),
                  status: sample.read('status', oneOf: [.ready, .sent]),
                  optionalStatus: sample.read(
                    'optionalStatus',
                    oneOf: [.ready, .sent],
                  ),
                  statuses: sample.readList('statuses', oneOf: [.ready, .sent]),
                ),
              ),
            );

            return {
              'size': EnumName(result.size).name,
              'status': EnumName(result.status).name,
              'optionalStatus': switch (result.optionalStatus) {
                null => null,
                final optionalStatus => EnumName(optionalStatus).name,
              },
              'statuses': [
                for (final item in result.statuses) EnumName(item).name,
              ],
            };
          },
        ),
      ],
    );
  }
}

mixin _$Shelf implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as Shelf;

    return AgentSchema(
      sees: const [],
      calls: [
        AgentTool(
          surface.stock,
          name: 'stock',
          description: 'Puts [skus] on the shelf.',
          parameters: const {
            'type': 'object',
            'properties': {
              'skus': {
                'type': 'array',
                'items': {'type': 'string'},
              },
              'size': {
                'anyOf': [
                  {
                    'type': 'string',
                    'enum': ['s', 'm', 'l'],
                  },
                  {'type': 'null'},
                ],
              },
              'count': {'type': 'integer'},
              'fit': {
                'type': 'string',
                'enum': ['s', 'm', 'l'],
              },
              'note': {
                'anyOf': [
                  {'type': 'string'},
                  {'type': 'null'},
                ],
              },
            },
            'required': ['skus'],
          },
          invoke: (args) {
            surface.stock(
              [for (final item in args.readList<String>('skus')) .new(item)],
              args.read('size', oneOf: [.s, .m, .l]),
              count: args.json.containsKey('count') ? args.read('count') : 1,
              fit: args.json.containsKey('fit')
                  ? args.read('fit', oneOf: [.s, .m, .l])
                  : .m,
              note: args.json.containsKey('note') ? args.read('note') : 'new',
            );
            return null;
          },
        ),
      ],
    );
  }
}

mixin _$Dispatch implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as Dispatch;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.lastBooked,
          'last_booked',
          'The delivery booked last, if any.',
          (lastBooked) => switch (lastBooked) {
            null => null,
            final lastBooked => {
              'address': {
                'street': lastBooked.address.street,
                'city': lastBooked.address.city,
              },
              'day': lastBooked.day.toIso8601String(),
              'slot': EnumName(lastBooked.slot).name,
              'note': lastBooked.note,
            },
          },
        ),
      ],
      calls: [
        AgentTool(
          surface.book,
          name: 'book',
          description:
              'Books a courier for [lines] and returns the delivery as booked.',
          parameters: const {
            'type': 'object',
            'properties': {
              'lines': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'description':
                      'One product of an order and how many pieces of it.',
                  'properties': {
                    'sku': {
                      'type': 'string',
                      'description': "The product's code in the catalog.",
                    },
                    'quantity': {
                      'type': 'integer',
                      'description': 'How many pieces.',
                    },
                  },
                  'required': ['sku', 'quantity'],
                },
              },
              'delivery': {
                'type': 'object',
                'description': 'Where and when an order goes.',
                'properties': {
                  'address': {
                    'type': 'object',
                    'description': 'Where the courier brings the order.',
                    'properties': {
                      'street': {'type': 'string'},
                      'city': {'type': 'string'},
                    },
                    'required': ['street', 'city'],
                  },
                  'day': {
                    'type': 'string',
                    'format': 'date-time',
                    'description': 'The day the order arrives.',
                  },
                  'slot': {
                    'type': 'string',
                    'enum': ['morning', 'afternoon'],
                  },
                  'note': {
                    'anyOf': [
                      {'type': 'string'},
                      {'type': 'null'},
                    ],
                    'description': 'Anything the courier should know.',
                  },
                },
                'required': ['address', 'day'],
              },
            },
            'required': ['lines', 'delivery'],
          },
          invoke: (args) async {
            final result = await surface.book(
              args.readObjects(
                'lines',
                (item) => .new(
                  sku: item.read('sku'),
                  quantity: item.read('quantity'),
                ),
              ),
              args.readObject(
                'delivery',
                (delivery) => .new(
                  address: delivery.readObject(
                    'address',
                    (address) => .new(
                      street: address.read('street'),
                      city: address.read('city'),
                    ),
                  ),
                  day: delivery.read('day'),
                  slot: delivery.json.containsKey('slot')
                      ? delivery.read('slot', oneOf: [.morning, .afternoon])
                      : .morning,
                  note: delivery.read('note'),
                ),
              ),
            );

            return {
              'address': {
                'street': result.address.street,
                'city': result.address.city,
              },
              'day': result.day.toIso8601String(),
              'slot': EnumName(result.slot).name,
              'note': result.note,
            };
          },
        ),
        AgentTool(
          surface.setDelivery,
          name: 'set_delivery',
          description: 'Replaces or clears the delivery.',
          parameters: const {
            'type': 'object',
            'properties': {
              'delivery': {
                'anyOf': [
                  {
                    'type': 'object',
                    'description': 'Where and when an order goes.',
                    'properties': {
                      'address': {
                        'type': 'object',
                        'description': 'Where the courier brings the order.',
                        'properties': {
                          'street': {'type': 'string'},
                          'city': {'type': 'string'},
                        },
                        'required': ['street', 'city'],
                      },
                      'day': {
                        'type': 'string',
                        'format': 'date-time',
                        'description': 'The day the order arrives.',
                      },
                      'slot': {
                        'type': 'string',
                        'enum': ['morning', 'afternoon'],
                      },
                      'note': {
                        'anyOf': [
                          {'type': 'string'},
                          {'type': 'null'},
                        ],
                        'description': 'Anything the courier should know.',
                      },
                    },
                    'required': ['address', 'day'],
                  },
                  {'type': 'null'},
                ],
              },
            },
          },
          invoke: (args) {
            surface.setDelivery(
              args.readObject(
                'delivery',
                (delivery) => .new(
                  address: delivery.readObject(
                    'address',
                    (address) => .new(
                      street: address.read('street'),
                      city: address.read('city'),
                    ),
                  ),
                  day: delivery.read('day'),
                  slot: delivery.json.containsKey('slot')
                      ? delivery.read('slot', oneOf: [.morning, .afternoon])
                      : .morning,
                  note: delivery.read('note'),
                ),
              ),
            );
            return null;
          },
        ),
        AgentTool(
          surface.findDelivery,
          name: 'find_delivery',
          description: 'Finds the last booked delivery, if any.',
          parameters: const {'type': 'object', 'properties': {}},
          invoke: (args) async {
            final result = await surface.findDelivery();

            return switch (result) {
              null => null,
              final result => {
                'address': {
                  'street': result.address.street,
                  'city': result.address.city,
                },
                'day': result.day.toIso8601String(),
                'slot': EnumName(result.slot).name,
                'note': result.note,
              },
            };
          },
        ),
        AgentTool(
          surface.deliveryDay,
          name: 'delivery_day',
          description: 'The day of the last booked delivery, if any.',
          parameters: const {'type': 'object', 'properties': {}},
          invoke: (args) async {
            final result = await surface.deliveryDay();

            return result?.toIso8601String();
          },
        ),
      ],
    );
  }
}
