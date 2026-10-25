import 'dart:async';

import 'package:example/agent_chat.dart';
import 'package:example/order.dart';
import 'package:example/order_cubit.dart';
import 'package:example/order_screen.dart';
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

  testWidgets('a line follows the state of the agent while it works', (
    tester,
  ) async {
    final history = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        const AgentStep.stateSnapshot({'step': 'Reading the order history'}),
        AgentStep.waitFor(history.future),
        const AgentStep.stateDelta([
          {'op': 'replace', 'path': '/step', 'value': 'Filling the order'},
        ]),
        const AgentStep.say('Done.'),
      ],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: TandemScope.connected(
            surface: (context) => context.read<OrderCubit>(),
            connection: agent,
            approvals: const .fromState(),
            child: const Column(
              children: [
                _AgentStep(),
                Expanded(child: AgentChat()),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'same as last time');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Reading the order history'), findsOneWidget);

    history.complete();
    await tester.pumpAndSettle();
    expect(find.text('Filling the order'), findsOneWidget);
  });

  testWidgets('a coding agent fills the order screen', (tester) async {
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: orders,
        child: const MaterialApp(home: OrderScreen()),
      ),
    );

    final answer = await TandemBridge.call(
      'set_quantity',
      arguments: {'sku': 'VM-27Q', 'quantity': 15},
    );
    await tester.pump();

    expect(answer['status'], 'returned');
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('a coding agent places the order once the user approves it', (
    tester,
  ) async {
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: orders,
        child: const MaterialApp(home: OrderScreen()),
      ),
    );
    await TandemBridge.call(
      'set_quantity',
      arguments: {'sku': 'VM-27Q', 'quantity': 2},
    );

    final answer = TandemBridge.call('place_order');
    await tester.pumpAndSettle();
    expect(orders.placed, isEmpty);
    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(await answer, containsPair('status', 'returned'));
    expect(orders.placed, hasLength(1));
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

/// The step that the agent's backend says it works on, from its state.
final class const _AgentStep() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      switch (TandemSessionScope.of(context).agentState) {
        {'step': final String step} => Text(step),
        _ => const SizedBox.shrink(),
      };
}
