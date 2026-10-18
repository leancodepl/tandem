import 'package:example/agent_chat.dart';
import 'package:example/order.dart';
import 'package:example/order_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  late Orders orders;
  late OrderCubit cubit;

  setUp(() {
    orders = Orders();
    cubit = OrderCubit(orders: orders);
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
  });

  testWidgets('the agent sets a quantity from the chat', (tester) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 15}),
      ],
      (_) => const [AgentStep.say('Done.')],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: TandemScope.connected(
            surface: (context) => context.read<OrderCubit>(),
            connection: agent,
            approvals: const .fromState(),
            child: const AgentChat(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'fifteen monitors');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(cubit.draft.lines.single.quantity, 15);
    expect(find.text('Done.'), findsOneWidget);
  });

  test(
    'every call checks the list as it is now, not as the run began',
    () async {
      cubit.setQuantity('VM-27Q', 2);
      final listing = AgentListing.of(cubit);

      await listing.call('set_quantity', {'sku': 'VM-27Q', 'quantity': 0});
      await expectLater(
        listing.call('place_order', {}, approved: true),
        throwsA(isA<ToolCallRefused>()),
      );
      expect(orders.placed, isEmpty);
    },
  );
}
