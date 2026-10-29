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
        AgentView.of(() => surface.sample).as(
          'sample',
          "The shelf's current and previous statuses.",
          .object(
            id: 'asset:example/test/parameters_test.dart#EnumSample',
            fields: (field) => [
              field('size', (value) => value.size).as(
                .enumeration([
                  .s,
                  .m,
                  .l,
                ], id: 'asset:example/test/parameters_test.dart#Size'),
              ),
              field('status', (value) => value.status).as(
                .enumeration([
                  .ready,
                  .sent,
                ], id: 'asset:example/test/parameters_test.dart#StockStatus'),
              ),
              field(
                'optionalStatus',
                (value) => value.optionalStatus,
                required: false,
              ).as(
                .nullable(
                  .enumeration([
                    .ready,
                    .sent,
                  ], id: 'asset:example/test/parameters_test.dart#StockStatus'),
                ),
              ),
              field('statuses', (value) => value.statuses).as(
                .list(
                  .enumeration([
                    .ready,
                    .sent,
                  ], id: 'asset:example/test/parameters_test.dart#StockStatus'),
                ),
              ),
            ],
            build: (values) => .new(
              size: values('size'),
              status: values('status'),
              optionalStatus: values('optionalStatus'),
              statuses: values('statuses'),
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.echo,
          name: 'echo',
          description: 'Stores and returns [sample].',
          parameters: [
            AgentParameter<EnumSample>(
              'sample',
              .object(
                id: 'asset:example/test/parameters_test.dart#EnumSample',
                fields: (field) => [
                  field('size', (value) => value.size).as(
                    .enumeration([
                      .s,
                      .m,
                      .l,
                    ], id: 'asset:example/test/parameters_test.dart#Size'),
                  ),
                  field('status', (value) => value.status).as(
                    .enumeration(
                      [.ready, .sent],
                      id: 'asset:example/test/parameters_test.dart#StockStatus',
                    ),
                  ),
                  field(
                    'optionalStatus',
                    (value) => value.optionalStatus,
                    required: false,
                  ).as(
                    .nullable(
                      .enumeration(
                        [.ready, .sent],
                        id: 'asset:example/test/parameters_test.dart#StockStatus',
                      ),
                    ),
                  ),
                  field('statuses', (value) => value.statuses).as(
                    .list(
                      .enumeration(
                        [.ready, .sent],
                        id: 'asset:example/test/parameters_test.dart#StockStatus',
                      ),
                    ),
                  ),
                ],
                build: (values) => .new(
                  size: values('size'),
                  status: values('status'),
                  optionalStatus: values('optionalStatus'),
                  statuses: values('statuses'),
                ),
              ),
            ),
          ],
          invoke: (args) {
            final result = surface.echo(args.read('sample'));

            return AgentResult(result).as(
              .object(
                id: 'asset:example/test/parameters_test.dart#EnumSample',
                fields: (field) => [
                  field('size', (value) => value.size).as(
                    .enumeration([
                      .s,
                      .m,
                      .l,
                    ], id: 'asset:example/test/parameters_test.dart#Size'),
                  ),
                  field('status', (value) => value.status).as(
                    .enumeration(
                      [.ready, .sent],
                      id: 'asset:example/test/parameters_test.dart#StockStatus',
                    ),
                  ),
                  field(
                    'optionalStatus',
                    (value) => value.optionalStatus,
                    required: false,
                  ).as(
                    .nullable(
                      .enumeration(
                        [.ready, .sent],
                        id: 'asset:example/test/parameters_test.dart#StockStatus',
                      ),
                    ),
                  ),
                  field('statuses', (value) => value.statuses).as(
                    .list(
                      .enumeration(
                        [.ready, .sent],
                        id: 'asset:example/test/parameters_test.dart#StockStatus',
                      ),
                    ),
                  ),
                ],
                build: (values) => .new(
                  size: values('size'),
                  status: values('status'),
                  optionalStatus: values('optionalStatus'),
                  statuses: values('statuses'),
                ),
              ),
            );
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
          parameters: [
            AgentParameter<List<Sku>>(
              'skus',
              .list(
                .extension(
                  .string,
                  (value) => .new(value),
                  id: 'asset:example/test/parameters_test.dart#Sku',
                ),
              ),
            ),
            AgentParameter<Size?>(
              'size',
              .nullable(
                .enumeration([
                  .s,
                  .m,
                  .l,
                ], id: 'asset:example/test/parameters_test.dart#Size'),
              ),
              required: false,
            ),
            const AgentParameter<int>('count', .integer, required: false),
            AgentParameter<Size>(
              'fit',
              .enumeration([
                .s,
                .m,
                .l,
              ], id: 'asset:example/test/parameters_test.dart#Size'),
              required: false,
            ),
            AgentParameter<String?>(
              'note',
              .nullable(.string),
              required: false,
            ),
          ],
          invoke: (args) {
            surface.stock(
              args.read('skus'),
              args.read('size'),
              count: args.has('count') ? args.read('count') : 1,
              fit: args.has('fit') ? args.read('fit') : .m,
              note: args.has('note') ? args.read('note') : 'new',
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
        AgentView.of(() => surface.lastBooked).as(
          'last_booked',
          'The delivery booked last, if any.',
          .nullable(
            .object(
              id: 'asset:example/test/delivery.dart#Delivery',
              description: 'Where and when an order goes.',
              fields: (field) => [
                field(
                  'address',
                  (value) => value.address,
                  description: 'Where the courier brings the order.',
                ).as(
                  .object(
                    id: 'asset:example/test/delivery.dart#Address',
                    description: 'A street address.',
                    fields: (field) => [
                      field('street', (value) => value.street).as(.string),
                      field('city', (value) => value.city).as(.string),
                    ],
                    build: (values) =>
                        .new(street: values('street'), city: values('city')),
                  ),
                ),
                field(
                  'day',
                  (value) => value.day,
                  description: 'The day the order arrives.',
                ).as(.dateTime),
                field('slot', (value) => value.slot, required: false).as(
                  .enumeration([
                    .morning,
                    .afternoon,
                  ], id: 'asset:example/test/delivery.dart#DeliverySlot'),
                ),
                field(
                  'note',
                  (value) => value.note,
                  description: 'Anything the courier should know.',
                  required: false,
                ).as(.nullable(.string)),
              ],
              build: (values) => .new(
                address: values('address'),
                day: values('day'),
                slot: values.has('slot') ? values('slot') : .morning,
                note: values('note'),
              ),
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.book,
          name: 'book',
          description:
              'Books a courier for [lines] and returns the delivery as booked.',
          parameters: [
            AgentParameter<List<OrderLine>>(
              'lines',
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
            AgentParameter<Delivery>(
              'delivery',
              .object(
                id: 'asset:example/test/delivery.dart#Delivery',
                description: 'Where and when an order goes.',
                fields: (field) => [
                  field(
                    'address',
                    (value) => value.address,
                    description: 'Where the courier brings the order.',
                  ).as(
                    .object(
                      id: 'asset:example/test/delivery.dart#Address',
                      description: 'A street address.',
                      fields: (field) => [
                        field('street', (value) => value.street).as(.string),
                        field('city', (value) => value.city).as(.string),
                      ],
                      build: (values) =>
                          .new(street: values('street'), city: values('city')),
                    ),
                  ),
                  field(
                    'day',
                    (value) => value.day,
                    description: 'The day the order arrives.',
                  ).as(.dateTime),
                  field('slot', (value) => value.slot, required: false).as(
                    .enumeration([
                      .morning,
                      .afternoon,
                    ], id: 'asset:example/test/delivery.dart#DeliverySlot'),
                  ),
                  field(
                    'note',
                    (value) => value.note,
                    description: 'Anything the courier should know.',
                    required: false,
                  ).as(.nullable(.string)),
                ],
                build: (values) => .new(
                  address: values('address'),
                  day: values('day'),
                  slot: values.has('slot') ? values('slot') : .morning,
                  note: values('note'),
                ),
              ),
            ),
          ],
          invoke: (args) async {
            final result = await surface.book(
              args.read('lines'),
              args.read('delivery'),
            );

            return AgentResult(result).as(
              .object(
                id: 'asset:example/test/delivery.dart#Delivery',
                description: 'Where and when an order goes.',
                fields: (field) => [
                  field(
                    'address',
                    (value) => value.address,
                    description: 'Where the courier brings the order.',
                  ).as(
                    .object(
                      id: 'asset:example/test/delivery.dart#Address',
                      description: 'A street address.',
                      fields: (field) => [
                        field('street', (value) => value.street).as(.string),
                        field('city', (value) => value.city).as(.string),
                      ],
                      build: (values) =>
                          .new(street: values('street'), city: values('city')),
                    ),
                  ),
                  field(
                    'day',
                    (value) => value.day,
                    description: 'The day the order arrives.',
                  ).as(.dateTime),
                  field('slot', (value) => value.slot, required: false).as(
                    .enumeration([
                      .morning,
                      .afternoon,
                    ], id: 'asset:example/test/delivery.dart#DeliverySlot'),
                  ),
                  field(
                    'note',
                    (value) => value.note,
                    description: 'Anything the courier should know.',
                    required: false,
                  ).as(.nullable(.string)),
                ],
                build: (values) => .new(
                  address: values('address'),
                  day: values('day'),
                  slot: values.has('slot') ? values('slot') : .morning,
                  note: values('note'),
                ),
              ),
            );
          },
        ),
        AgentTool(
          surface.setDelivery,
          name: 'set_delivery',
          description: 'Replaces or clears the delivery.',
          parameters: [
            AgentParameter<Delivery?>(
              'delivery',
              .nullable(
                .object(
                  id: 'asset:example/test/delivery.dart#Delivery',
                  description: 'Where and when an order goes.',
                  fields: (field) => [
                    field(
                      'address',
                      (value) => value.address,
                      description: 'Where the courier brings the order.',
                    ).as(
                      .object(
                        id: 'asset:example/test/delivery.dart#Address',
                        description: 'A street address.',
                        fields: (field) => [
                          field('street', (value) => value.street).as(.string),
                          field('city', (value) => value.city).as(.string),
                        ],
                        build: (values) => .new(
                          street: values('street'),
                          city: values('city'),
                        ),
                      ),
                    ),
                    field(
                      'day',
                      (value) => value.day,
                      description: 'The day the order arrives.',
                    ).as(.dateTime),
                    field('slot', (value) => value.slot, required: false).as(
                      .enumeration([
                        .morning,
                        .afternoon,
                      ], id: 'asset:example/test/delivery.dart#DeliverySlot'),
                    ),
                    field(
                      'note',
                      (value) => value.note,
                      description: 'Anything the courier should know.',
                      required: false,
                    ).as(.nullable(.string)),
                  ],
                  build: (values) => .new(
                    address: values('address'),
                    day: values('day'),
                    slot: values.has('slot') ? values('slot') : .morning,
                    note: values('note'),
                  ),
                ),
              ),
              required: false,
            ),
          ],
          invoke: (args) {
            surface.setDelivery(args.read('delivery'));
            return null;
          },
        ),
        AgentTool(
          surface.findDelivery,
          name: 'find_delivery',
          description: 'Finds the last booked delivery, if any.',
          parameters: [],
          invoke: (args) async {
            final result = await surface.findDelivery();

            return AgentResult(result).as(
              .nullable(
                .object(
                  id: 'asset:example/test/delivery.dart#Delivery',
                  description: 'Where and when an order goes.',
                  fields: (field) => [
                    field(
                      'address',
                      (value) => value.address,
                      description: 'Where the courier brings the order.',
                    ).as(
                      .object(
                        id: 'asset:example/test/delivery.dart#Address',
                        description: 'A street address.',
                        fields: (field) => [
                          field('street', (value) => value.street).as(.string),
                          field('city', (value) => value.city).as(.string),
                        ],
                        build: (values) => .new(
                          street: values('street'),
                          city: values('city'),
                        ),
                      ),
                    ),
                    field(
                      'day',
                      (value) => value.day,
                      description: 'The day the order arrives.',
                    ).as(.dateTime),
                    field('slot', (value) => value.slot, required: false).as(
                      .enumeration([
                        .morning,
                        .afternoon,
                      ], id: 'asset:example/test/delivery.dart#DeliverySlot'),
                    ),
                    field(
                      'note',
                      (value) => value.note,
                      description: 'Anything the courier should know.',
                      required: false,
                    ).as(.nullable(.string)),
                  ],
                  build: (values) => .new(
                    address: values('address'),
                    day: values('day'),
                    slot: values.has('slot') ? values('slot') : .morning,
                    note: values('note'),
                  ),
                ),
              ),
            );
          },
        ),
        AgentTool(
          surface.deliveryDay,
          name: 'delivery_day',
          description: 'The day of the last booked delivery, if any.',
          parameters: [],
          invoke: (args) async {
            final result = await surface.deliveryDay();

            return AgentResult(result).as(.nullable(.dateTime));
          },
        ),
      ],
    );
  }
}
