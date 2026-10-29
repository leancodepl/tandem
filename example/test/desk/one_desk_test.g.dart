// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'one_desk_test.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ShopAgent implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ShopAgent;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.order).as(
          'order',
          'The order as the user sees it on the desk.',
          .object(
            id: 'package:example/desk/desk_order.dart#DeskOrder',
            fields: (field) => [
              field('customer', (value) => value.customer, required: false).as(
                .nullable(
                  .object(
                    id: 'package:example/desk/customers.dart#Customer',
                    fields: (field) => [
                      field('id', (value) => value.id).as(.string),
                      field('name', (value) => value.name).as(.string),
                      field('contact', (value) => value.contact).as(.string),
                      field(
                        'priceList',
                        (value) => value.priceList,
                      ).as(.string),
                    ],
                    build: (values) => .new(
                      id: values('id'),
                      name: values('name'),
                      contact: values('contact'),
                      priceList: values('priceList'),
                    ),
                  ),
                ),
              ),
              field('lines', (value) => value.lines).as(
                .list(
                  .object(
                    id: 'package:example/desk/desk_order.dart#DeskLine',
                    fields: (field) => [
                      field('sku', (value) => value.sku).as(.string),
                      field('name', (value) => value.name).as(.string),
                      field('quantity', (value) => value.quantity).as(.integer),
                      field(
                        'unitPrice',
                        (value) => value.unitPrice,
                      ).as(.string),
                      field(
                        'discount',
                        (value) => value.discount,
                        required: false,
                      ).as(.nullable(.string)),
                      field(
                        'lineTotal',
                        (value) => value.lineTotal,
                      ).as(.string),
                    ],
                    build: (values) => .new(
                      sku: values('sku'),
                      name: values('name'),
                      quantity: values('quantity'),
                      unitPrice: values('unitPrice'),
                      discount: values('discount'),
                      lineTotal: values('lineTotal'),
                    ),
                  ),
                ),
              ),
              field('delivery', (value) => value.delivery, required: false).as(
                .nullable(
                  .object(
                    id: 'package:example/desk/desk_order.dart#DeskDelivery',
                    fields: (field) => [
                      field('address', (value) => value.address).as(.string),
                      field('date', (value) => value.date).as(.dateTime),
                    ],
                    build: (values) =>
                        .new(address: values('address'), date: values('date')),
                  ),
                ),
              ),
              field('total', (value) => value.total).as(.string),
            ],
            build: (values) => .new(
              customer: values('customer'),
              lines: values('lines'),
              delivery: values('delivery'),
              total: values('total'),
            ),
          ),
        ),
        AgentView.of(() => surface.catalog).as(
          'catalog',
          'The products of the shop.',
          .list(
            .object(
              id: 'package:example/desk/catalog.dart#Product',
              fields: (field) => [
                field('sku', (value) => value.sku).as(.string),
                field('name', (value) => value.name).as(.string),
                field('description', (value) => value.description).as(.string),
                field('price', (value) => value.price).as(.number),
              ],
              build: (values) => .new(
                sku: values('sku'),
                name: values('name'),
                description: values('description'),
                price: values('price'),
              ),
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.setQuantity,
          name: 'set_quantity',
          description: 'Sets how many pieces of [sku] the order has; 0 removes the line.',
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
          name: 'place_order',
          description: 'Places the order exactly as it is on the desk.',
          parameters: [],
          invoke: (args) async {
            final result = await surface.placeOrder();

            return AgentResult(result).as(
              .extension(
                .string,
                (value) => .new(value),
                id: 'package:example/desk/desk_order.dart#OrderId',
              ),
            );
          },
        ),
        AgentTool(
          surface.openCatalog,
          name: 'open_catalog',
          description: 'Opens the catalog of products.',
          parameters: [],
          invoke: (args) {
            surface.openCatalog();
            return null;
          },
        ),
        AgentTool(
          surface.openDesk,
          name: 'open_desk',
          description: 'Opens the order desk.',
          parameters: [],
          invoke: (args) {
            surface.openDesk();
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on ShopAgent {
  List<AgentCapability> get _$agentCapabilities => switch (routes.current) {
    '/desk' => [
      .seesAs('order', order),
      .calls(setQuantity),
      if (desk.canPlace) .callsWithApproval(placeOrder),
      .calls(openCatalog),
    ],
    '/catalog' => [.seesAs('catalog', catalog), .calls(openDesk)],
    _ => [.calls(openDesk)],
  };
}
