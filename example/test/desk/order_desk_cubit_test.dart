import 'dart:async';

import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/testing.dart';

const _cables = 'VC-HDMI-2M';
const _monitor = 'VM-27Q';
const _otherMonitor = 'VM-27U';
const _address = 'Magazynowa 5, 61-001 Poznań';

void main() {
  late Orders orders;
  late OrderDeskCubit cubit;

  setUp(() {
    orders = Orders();
    cubit = OrderDeskCubit(
      catalog: Catalog(products),
      customers: Customers(customers),
      orders: orders,
    );
  });

  tearDown(() => cubit.close());

  DeskLine lineOf(String sku) =>
      cubit.order.lines.firstWhere((line) => line.sku == sku);

  test("prices follow the customer's price list and the 15+ tier", () {
    cubit
      ..setQuantity(_cables, 40)
      ..setQuantity(_monitor, 1);
    expect(lineOf(_monitor).unitPrice, '1 249.00 PLN');
    expect(lineOf(_monitor).discount, isNull);

    cubit
      ..setCustomer('acme')
      ..setQuantity(_monitor, 12);
    expect(lineOf(_cables).unitPrice, '29.00 PLN');
    expect(lineOf(_cables).discount, isNull);
    expect(lineOf(_monitor).unitPrice, '1 099.12 PLN');
    expect(lineOf(_monitor).discount, '12 %');
    expect(lineOf(_monitor).lineTotal, '13 189.44 PLN');
    expect(cubit.order.total, '14 349.44 PLN');

    cubit.setQuantity(_monitor, 14);
    expect(lineOf(_monitor).unitPrice, '1 099.12 PLN');

    cubit.setQuantity(_monitor, 15);
    expect(lineOf(_monitor).unitPrice, '1 036.67 PLN');
    expect(lineOf(_monitor).discount, '17 %');
    expect(cubit.order.total, '16 710.05 PLN');

    cubit
      ..setQuantity(_monitor, 10)
      ..setQuantity(_otherMonitor, 5);
    expect(lineOf(_otherMonitor).unitPrice, '1 410.17 PLN');
  });

  test('the agent gets place_order only with lines, customer and delivery', () {
    const editing = [
      'search_catalog',
      'set_customer',
      'set_quantity',
      'set_delivery',
    ];
    expect(AgentListing.of(cubit).tools.map((tool) => tool['name']), editing);

    cubit
      ..setCustomer('acme')
      ..setQuantity(_monitor, 12);
    expect(AgentListing.of(cubit).tools.map((tool) => tool['name']), editing);

    cubit.setDelivery(_address, DateTime(2026, 10, 23));
    final listing = AgentListing.of(cubit);

    expect(listing.tools.map((tool) => tool['name']), contains('place_order'));
    expect(listing.needsApproval('place_order'), isTrue);
    expect(listing.context.single['description'], startsWith('order: '));
    expect(listing.context.single['value'], contains('13 189.44 PLN'));
    expect(listing.context.single['value'], contains('Acme 2026'));
  });

  test('the agent reads the doc comments and calls the methods', () async {
    cubit
      ..setCustomer('northline')
      ..setQuantity(_cables, 1)
      ..setDelivery('Logistyczna 1, 05-800 Pruszków', DateTime(2026, 10, 20));
    final listing = AgentListing.of(cubit);
    expect(
      {for (final tool in listing.tools) tool['name']: tool['description']},
      {
        'search_catalog': 'Finds products by SKU, name or description.',
        'set_customer': 'Sets the customer the order is for; prices follow their price list.',
        'set_quantity':
            'Sets how many pieces of [sku] the order has; 0 removes the line.',
        'set_delivery': 'Sets where and when the order is delivered.',
        'place_order': 'Places the order exactly as it is on the screen.',
      },
    );

    await listing.call('set_customer', {'customerId': 'acme'});
    await listing.call('set_delivery', {
      'address': _address,
      'date': '2026-10-23',
    });
    final found = await listing.call('search_catalog', {'query': 'hdmi cable'});

    expect(cubit.order.customer?.name, 'Acme Office Supply Sp. z o.o.');
    expect(cubit.order.delivery?.address, _address);
    expect(cubit.order.delivery?.date, DateTime(2026, 10, 23));
    expect(found, [containsPair('sku', _cables)]);
  });

  test('search matches every word of the query', () async {
    expect(
      [for (final p in await cubit.searchCatalog('HDMI cable 2 m')) p.sku],
      [_cables],
    );
    expect(
      [for (final p in await cubit.searchCatalog('27-inch monitor')) p.sku],
      [_monitor, _otherMonitor],
    );
  });

  test('unknown customers and skus and negative quantities are refused', () {
    expect(() => cubit.setCustomer('nobody'), throwsArgumentError);
    expect(() => cubit.setQuantity('VX-1', 1), throwsArgumentError);
    expect(() => cubit.setQuantity(_monitor, -1), throwsArgumentError);
    expect(cubit.order.lines, isEmpty);
  });

  test('a quantity of 0 removes the line', () {
    cubit
      ..setQuantity(_cables, 4)
      ..setQuantity(_cables, 0);

    expect(cubit.order.lines, isEmpty);
    expect(cubit.order.total, '0.00 PLN');
  });

  test('placing the order gives ORD-1042 and keeps it, read-only', () async {
    cubit
      ..setCustomer('acme')
      ..setQuantity(_monitor, 2)
      ..setDelivery(_address, DateTime(2026, 10, 23));
    expect(cubit.canPlace, isTrue);

    final id = await AgentListing.of(cubit)
        .call('place_order', {}, approved: true);

    expect(id, 'ORD-1042');
    expect(orders.placed.single.total, '2 198.24 PLN');
    expect(cubit.placed?.id.value, 'ORD-1042');
    expect(cubit.order.customer?.name, 'Acme Office Supply Sp. z o.o.');
    expect(cubit.order.lines.single.quantity, 2);
    expect(cubit.canPlace, isFalse);
    expect(cubit.canEdit, isFalse);
    expect(AgentListing.of(cubit).tools.map((tool) => tool['name']), [
      'search_catalog',
    ]);
  });

  test('what is changed while the order is placed is not part of it', () async {
    final gate = Completer<void>();
    final slowCubit = OrderDeskCubit(
      catalog: Catalog(products),
      customers: Customers(customers),
      orders: _SlowOrders(gate.future),
    )..setQuantity(_monitor, 2);
    addTearDown(slowCubit.close);

    final placing = slowCubit.placeOrder();
    slowCubit.setQuantity(_monitor, 3);
    gate.complete();
    await placing;

    expect(slowCubit.placed?.order.lines.single.quantity, 2);
    expect(slowCubit.orders.placed.single.lines.single.quantity, 2);
    expect(slowCubit.order.lines.single.quantity, 3);
  });

  test('an order placed while the screen closes throws nothing', () async {
    cubit.setQuantity(_monitor, 2);

    final placing = cubit.placeOrder();
    await cubit.close();

    await expectLater(placing, completion(const OrderId('ORD-1042')));
    expect(orders.placed, hasLength(1));
  });
}

final class _SlowOrders(final Future<void> gate) extends Orders {
  @override
  Future<OrderId> place(DeskOrder order) async {
    await gate;
    return await super.place(order);
  }
}
