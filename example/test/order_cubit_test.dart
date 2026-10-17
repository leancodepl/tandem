import 'package:example/order.dart';
import 'package:example/order_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/tandem_bloc.dart';
import 'package:tandem_bloc/testing.dart';

void main() {
  late Orders orders;
  late OrderCubit cubit;

  setUp(() {
    orders = Orders();
    cubit = OrderCubit(
      catalog: Catalog([
        const .new(
          sku: 'VM-27Q',
          name: 'Monitor 27"',
          description: 'QHD IPS monitor',
        ),
      ]),
      orders: orders,
    );
  });

  tearDown(() => cubit.close());

  test('the agent gets the doc comments, the schemas and the draft', () {
    final listing = AgentListing.of(cubit);

    expect(listing.context, [
      {
        'description': 'draft: The order as the user sees it on the screen.',
        'value': '{"lines":[]}',
      },
    ]);
    expect(listing.tools, [
      {
        'name': 'search_catalog',
        'description': 'Finds products by name or description.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
          'required': ['query'],
        },
      },
      {
        'name': 'set_quantity',
        'description': 'Sets how many pieces of [sku] the order has.',
        'parameters': {
          'type': 'object',
          'properties': {
            'sku': {'type': 'string'},
            'quantity': {'type': 'integer'},
          },
          'required': ['sku', 'quantity'],
        },
      },
    ]);
  });

  test('a call runs the method, and the next run sees the change', () async {
    // Models often send whole numbers as 15.0.
    await AgentListing.of(cubit)
        .call('set_quantity', {'sku': 'VM-27Q', 'quantity': 15.0});

    final next = AgentListing.of(cubit);
    expect(
      next.context.single['value'],
      '{"lines":[{"sku":"VM-27Q","quantity":15}]}',
    );
    expect(next.tools.map((tool) => tool['name']), contains('place_order'));
    expect(next.needsApproval('place_order'), isTrue);
  });

  test('place_order runs only while listed and only once approved', () async {
    await expectLater(
      AgentListing.of(cubit).call('place_order', {}),
      throwsA(isA<ToolCallRefused>()),
    );

    cubit.setQuantity('VM-27Q', 2);
    final listing = AgentListing.of(cubit);
    await expectLater(
      listing.call('place_order', {}),
      throwsA(isA<ToolCallRefused>()),
    );
    expect(await listing.call('place_order', {}, approved: true), 'ORD-1');
    expect(cubit.draft.lines, isEmpty);
  });

  test('an edit made while the order is placed stays on the screen', () async {
    cubit.setQuantity('VM-27Q', 2);

    final placing = cubit.placeOrder();
    cubit.setQuantity('VM-27Q', 3);
    await placing;

    expect(orders.placed.single.lines.map((line) => line.quantity), [2]);
    expect(cubit.draft.lines.map((line) => line.quantity), [3]);
  });

  test('an order placed while the screen closes throws nothing', () async {
    cubit.setQuantity('VM-27Q', 2);

    final placing = cubit.placeOrder();
    await cubit.close();

    await expectLater(placing, completion('ORD-1'));
  });

  test(
    'every call checks the list as it is now, not as the run began',
    () async {
      cubit.setQuantity('VM-27Q', 2);
      final listing = AgentListing.of(cubit);

      // Emptying the draft takes place_order off the list mid-run.
      await listing.call('set_quantity', {'sku': 'VM-27Q', 'quantity': 0});
      await expectLater(
        listing.call('place_order', {}, approved: true),
        throwsA(isA<ToolCallRefused>()),
      );
      expect(orders.placed, isEmpty);
    },
  );
}
