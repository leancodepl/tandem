import 'dart:convert';

import 'package:example/agent_chat.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/ui/order_desk_screen.dart';
import 'package:example/desk/ui/order_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/testing.dart';

const _empty = 'Paste a customer e-mail into the chat to start an order.';
const _customer = 'Acme Office Supply Sp. z o.o.';
const _cables = 'VC-HDMI-2M';
const _cablesName = 'HDMI 2.1 cable, 2 m';
const _monitor = 'VM-27Q';
const _monitorName = 'Voltra ProView 27Q, 27" QHD monitor';
const _address = 'Magazynowa 5, 61-001 Poznań';

const _fillOrder = [
  AgentStep.callTool('set_customer', {'customerId': 'acme'}),
  AgentStep.callTool('set_quantity', {'sku': _cables, 'quantity': 40}),
  AgentStep.callTool('set_quantity', {'sku': _monitor, 'quantity': 12}),
  AgentStep.callTool('set_delivery', {
    'address': _address,
    'date': '2026-10-23',
  }),
];

void main() {
  testWidgets(
    'the agent fills the order from the e-mail and places it after approval',
    (tester) async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('set_customer', {'customerId': 'acme'}),
          AgentStep.callTool('search_catalog', {'query': 'HDMI cable 2 m'}),
          AgentStep.callTool('search_catalog', {'query': '27-inch monitor'}),
        ],
        (_) => const [
          AgentStep.say(
            'I assumed the ProView 27Q, as in your September order ORD-0987.',
          ),
          AgentStep.callTool('set_quantity', {'sku': _cables, 'quantity': 40}),
          AgentStep.callTool('set_quantity', {'sku': _monitor, 'quantity': 12}),
          AgentStep.callTool('set_delivery', {
            'address': _address,
            'date': '2026-10-23',
          }),
        ],
        (request) => [
          AgentStep.say(
            '40 HDMI cables and 12 ProView 27Q monitors, delivered on 23 Oct. '
            'Total ${_totalSeen(request)}. Shall I place it?',
          ),
        ],
        (_) => const [
          AgentStep.say(
            "You changed the monitors to 15, which unlocks Acme's 15+ tier "
            '(17 % off monitors).',
          ),
          AgentStep.callTool('place_order'),
        ],
        (_) => const [AgentStep.say('Order ORD-1042 placed for 23 Oct.')],
      ]);
      await _pumpScreen(tester, agent);
      expect(find.text(_empty), findsOneWidget);

      await _send(
        tester,
        'Hi, could you send us 40 HDMI cables (2 m) and 12 of the 27-inch '
        'monitors like last time? Delivery to Magazynowa 5, Poznań by Friday '
        'please. Thanks, Marta, Acme Office Supply',
      );

      expect(find.text(_empty), findsNothing);
      expect(find.text(_customer), findsOneWidget);
      expect(find.text(_cablesName), findsOneWidget);
      expect(find.text(_monitorName), findsOneWidget);
      expect(find.text('1 099.12 PLN'), findsOneWidget);
      expect(find.text('12 %'), findsOneWidget);
      expect(find.text(_address), findsOneWidget);
      expect(find.text('Oct 23, 2026'), findsOneWidget);
      expect(find.text('14 349.44 PLN'), findsOneWidget);
      expect(
        find.text(
          '40 HDMI cables and 12 ProView 27Q monitors, delivered on 23 Oct. '
          'Total 14 349.44 PLN. Shall I place it?',
        ),
        findsOneWidget,
      );

      for (var tap = 0; tap < 3; tap++) {
        await tester.tap(_plusOf(_monitor));
        await tester.pump();
      }

      expect(find.text('16 710.05 PLN'), findsOneWidget);
      expect(find.text('17 %'), findsOneWidget);

      await _send(tester, 'Looks good, place it');

      expect(_inChat('Place order for $_customer'), findsOneWidget);
      expect(_inChat('40 × $_cablesName'), findsOneWidget);
      expect(_inChat('15 × $_monitorName'), findsOneWidget);
      expect(_inChat('15 550.05 PLN'), findsOneWidget);
      expect(_inChat('Delivery: $_address, Oct 23, 2026'), findsOneWidget);
      expect(_inChat('16 710.05 PLN'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Order ORD-1042 placed for 23 Oct.'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Placed as ORD-1042'), findsOneWidget);
      expect(find.text('Delivery on Oct 23, 2026'), findsOneWidget);
      expect(find.text(_customer), findsOneWidget);
      expect(find.text(_monitorName), findsOneWidget);
      expect(find.text(_empty), findsNothing);
      expect(
        find.descendant(of: find.byType(OrderForm), matching: _enabledButton),
        findsNothing,
      );
      final cubit = tester
          .element(find.byType(AgentChat))
          .read<OrderDeskCubit>();
      expect(cubit.orders.placed.single.total, '16 710.05 PLN');

      final requests = agent.requests;
      final secondTurnAnswers = _messagesOf(requests[2]).reversed.take(3);
      expect(
        secondTurnAnswers.map((message) => message['role']),
        everyElement('tool'),
      );
      expect(
        secondTurnAnswers.map((message) => message['content']),
        everyElement('null'),
      );
      expect(
        _messagesOf(requests[3]).last,
        containsPair('content', 'Looks good, place it'),
      );
      expect(_totalSeen(requests[3]), '16 710.05 PLN');
      expect(_toolsOffered(requests[3]), contains('place_order'));
      expect(
        _messagesOf(requests[4]).last,
        containsPair('content', '"ORD-1042"'),
      );
      expect(_toolsOffered(requests[4]), ['search_catalog']);
    },
  );

  testWidgets('a new delivery date from the picker invalidates the card', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      ScriptedAgent([
        (_) => const [
          AgentStep.callTool('set_customer', {'customerId': 'acme'}),
          AgentStep.callTool('set_quantity', {'sku': _monitor, 'quantity': 2}),
          AgentStep.callTool('set_delivery', {
            'address': _address,
            'date': '2026-10-23',
          }),
        ],
        (_) => const [AgentStep.callTool('place_order')],
      ]),
    );
    await _send(tester, 'Order two monitors');
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Oct 23, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Oct 24, 2026'), findsOneWidget);
    expect(_inChat('Delivery: $_address, Oct 24, 2026'), findsOneWidget);
    expect(
      find.text('The screen changed. Ask the agent again.'),
      findsOneWidget,
    );
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('the filled order fits an iPad held upright', (tester) async {
    await _pumpScreen(
      tester,
      ScriptedAgent([
        (_) => _fillOrder,
        (_) => const [AgentStep.say('Done.')],
      ]),
      size: const Size(834, 1194),
    );

    await _send(tester, 'Order');

    expect(find.text(_monitorName), findsOneWidget);
    expect(find.text('14 349.44 PLN'), findsOneWidget);
  });
}

String _totalSeen(Map<String, Object?> request) {
  if (request case {'context': [{'value': final String order}]}) {
    if (jsonDecode(order) case {'total': final String total}) {
      return total;
    }
  }
  throw StateError('The request has no order in its context: $request');
}

List<Map<String, Object?>> _messagesOf(Map<String, Object?> request) {
  if (request case {'messages': final List<Object?> messages}) {
    return messages.cast();
  }
  throw StateError('The request has no messages: $request');
}

List<Object?> _toolsOffered(Map<String, Object?> request) {
  if (request case {'tools': final List<Object?> tools}) {
    return [
      for (final tool in tools)
        if (tool case {'name': final name}) name,
    ];
  }
  throw StateError('The request has no tools: $request');
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ScriptedAgent agent, {
  Size size = const Size(1180, 820), // An iPad Pro 11" in landscape.
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: OrderDeskScreen(connection: agent)),
  );
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
}

Finder _plusOf(String sku) => find.descendant(
  of: find.byKey(ValueKey(sku)),
  matching: find.byIcon(Icons.add),
);

final _enabledButton = find.byWidgetPredicate(
  (widget) => switch (widget) {
    IconButton(:final onPressed) ||
    ButtonStyleButton(:final onPressed) => onPressed != null,
    _ => false,
  },
);

Finder _inChat(String text) =>
    find.descendant(of: find.byType(AgentChat), matching: find.text(text));
