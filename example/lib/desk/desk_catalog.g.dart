// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desk_catalog.dart';

// **************************************************************************
// CatalogGenerator
// **************************************************************************

mixin _$DeskCatalog implements AgentCatalog {
  @override
  String get guidelines =>
      'Start with a DeskCard. Show the customer as a CustomerCard, the order lines as one OrderLine per item of /order/lines, then an OrderTotal of /order, then a DeskButton for place_order when it is among your tools.';

  @override
  List<Map<String, Object?>> get example => const [
    {
      'id': 'root',
      'component': 'DeskCard',
      'title': 'Your order',
      'children': ['customer', 'lines', 'total', 'place'],
    },
    {
      'id': 'customer',
      'component': 'CustomerCard',
      'customer': {'path': '/order/customer'},
    },
    {
      'id': 'lines',
      'component': 'DeskColumn',
      'children': {'componentId': 'line', 'path': '/order/lines'},
    },
    {
      'id': 'line',
      'component': 'OrderLine',
      'name': {'path': 'name'},
      'quantity': {'path': 'quantity'},
      'lineTotal': {'path': 'lineTotal'},
      'onRemove': {
        'action': {
          'event': {
            'name': 'set_quantity',
            'context': {
              'sku': {'path': 'sku'},
              'quantity': 0,
            },
          },
        },
      },
      'onQuantity': {
        'action': {
          'event': {
            'name': 'set_quantity',
            'context': {
              'sku': {'path': 'sku'},
              'quantity': {'input': true},
            },
          },
        },
      },
    },
    {
      'id': 'total',
      'component': 'OrderTotal',
      'order': {'path': '/order'},
    },
    {
      'id': 'place',
      'component': 'DeskButton',
      'label': 'Place order',
      'icon': 'cart',
      'onPressed': {
        'action': {
          'event': {'name': 'place_order'},
        },
      },
    },
  ];

  @override
  List<AgentComponent> get components => [
    AgentComponent<DeskCard>.of(
      name: 'DeskCard',
      description: 'A card with a title over its children, such as the summary of the order.',
      properties: (property) => [
        property('title', (widget) => widget.title).value(.string),
        property.children('children'),
      ],
      build: (args) => DeskCard(
        title: args.value('title'),
        children: args.children('children'),
      ),
    ),
    AgentComponent<DeskColumn>.of(
      name: 'DeskColumn',
      description:
          'Components one below another, such as the lines of the order.',
      properties: (property) => [property.children('children')],
      build: (args) => DeskColumn(children: args.children('children')),
    ),
    AgentComponent<OrderLine>.of(
      name: 'OrderLine',
      description:
          'One line of the order: the product, how many, and the line total.',
      properties: (property) => [
        property('name', (widget) => widget.name).value(.string),
        property('quantity', (widget) => widget.quantity).value(.integer),
        property('lineTotal', (widget) => widget.lineTotal).value(.string),
        property.press('onRemove', required: false),
        property
            .field('onQuantity', (widget) => widget.onQuantity)
            .as(.integer, required: false),
      ],
      build: (args) => OrderLine(
        name: args.value('name'),
        quantity: args.value('quantity'),
        lineTotal: args.value('lineTotal'),
        onRemove: args.pressOrNull('onRemove'),
        onQuantity: args.fieldOrNull('onQuantity'),
      ),
    ),
    AgentComponent<OrderTotal>.of(
      name: 'OrderTotal',
      description:
          'What the whole order comes to, with how many pieces it has.',
      properties: (property) => [
        property('order', (widget) => widget.order).value(
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
      ],
      build: (args) => OrderTotal(order: args.value('order')),
    ),
    AgentComponent<DeskButton>.of(
      name: 'DeskButton',
      description:
          'A button that does what its label says, such as placing the order.',
      properties: (property) => [
        property('label', (widget) => widget.label).value(.string),
        property.press('onPressed', required: false),
        property('icon', (widget) => widget.icon).value(
          .nullable(
            .converted(
              _$DeskCatalogConverters[0],
              .string,
              id: 'package:flutter/src/widgets/icon_data.dart#IconData',
              converterId:
                  'package:example/desk/desk_catalog.dart#DeskIconConverter()',
              description: 'An icon by name: cart, truck or receipt.',
            ),
          ),
          required: false,
        ),
      ],
      build: (args) => DeskButton(
        label: args.value('label'),
        onPressed: args.pressOrNull('onPressed'),
        icon: args.value('icon'),
      ),
    ),
    AgentComponent<CustomerCard>.of(
      name: 'CustomerCard',
      description: 'The customer the order is for, with their price list.',
      properties: (property) => [
        property('customer', (widget) => widget.customer).value(
          .object(
            id: 'package:example/desk/customers.dart#Customer',
            fields: (field) => [
              field('id', (value) => value.id).as(.string),
              field('name', (value) => value.name).as(.string),
              field('contact', (value) => value.contact).as(.string),
              field('priceList', (value) => value.priceList).as(.string),
            ],
            build: (values) => .new(
              id: values('id'),
              name: values('name'),
              contact: values('contact'),
              priceList: values('priceList'),
            ),
          ),
        ),
      ],
      build: (args) => CustomerCard(customer: args.value('customer')),
    ),
  ];
}

const List<Object> _$DeskCatalogConverters = [DeskIconConverter()];
