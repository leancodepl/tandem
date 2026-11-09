// Runs only with AGENT_URL, the endpoint of an agent in example/agents that
// plays its scripted model. The command is in AGENTS.md.
@TestOn('vm')
library;

import 'dart:io';

import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/emails.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

const _agentUrl = String.fromEnvironment('AGENT_URL');

void main() {
  testWidgets(
    'the agent server fills the order and places it after approval',
    skip: _agentUrl.isEmpty,
    (tester) async {
      // Otherwise flutter_test answers every request with a 400.
      HttpOverrides.global = null;
      final orders = Orders();
      final order = OrderDeskCubit(
        catalog: Catalog(products),
        customers: Customers(customers),
        orders: orders,
      );
      addTearDown(order.close);
      late TandemSession session;
      await tester.pumpWidget(
        TandemScope(
          surface: (context) => order,
          agent: Uri.parse(_agentUrl),
          approvals: const .fromState(),
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      session.send(orderEmail);
      await _settle(tester, session);
      session.send('Looks good, place it');
      await _settle(tester, session);
      if (session.status case AwaitingApproval(:final request)) {
        session.approve(request);
      }
      await _settle(tester, session);

      const summary =
          '40 HDMI cables and 12 ProView 27Q monitors, delivered on 23 Oct. '
          'Total 14 349.44 PLN. Shall I place it?';
      expect(_chat(session), [
        'user: $orderEmail',
        'agent: I assumed the ProView 27Q, as in your September order ORD-0987.',
        'agent: $summary',
        'user: Looks good, place it',
        'place_order: approved',
        'agent: Order ORD-1042 placed for 23 Oct.',
      ]);
      expect(order.state.quantities, {'VC-HDMI-2M': 40, 'VM-27Q': 12});
      expect(orders.placed, hasLength(1));
    },
  );
}

// The fake clock of a widget test does not wait for a real socket.
Future<void> _settle(WidgetTester tester, TandemSession session) async {
  for (var round = 0; round < 6000; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (session.status case Idle() || AwaitingApproval()) {
      return;
    }
  }
  fail('The agent took longer than 60 s.');
}

List<String> _chat(TandemSession session) => [
  for (final item in session.items)
    switch (item) {
      UserMessage(:final text) => 'user: $text',
      AgentMessage(:final text) => 'agent: $text',
      ApprovalRequest(:final tool, :final status) => '$tool: ${status.name}',
      ChatNotice(:final kind) => 'notice: ${kind.name}',
    },
];
