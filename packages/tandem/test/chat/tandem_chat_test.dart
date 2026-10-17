import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/shop.dart';

void main() {
  testWidgets("shows the agent's text and a default card it can approve", (
    tester,
  ) async {
    final shop = await _sendClear(tester, [
      (_) => const [
        AgentStep.say('Clear the list?'),
        AgentStep.callTool('clear'),
      ],
      (_) => const [AgentStep.say('Cleared.')],
    ]);

    expect(find.text('Clear the list?'), findsOneWidget);
    expect(find.text('Empties the list.'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Cleared.'), findsOneWidget);
    expect(shop.items, isEmpty);
  });

  testWidgets('a custom card shows what approvalBuilder builds, for the '
      'request of that card', (tester) async {
    await _sendClear(
      tester,
      [
        (_) => const [AgentStep.callTool('clear')],
        (_) => const [AgentStep.callTool('clear')],
      ],
      approvalBuilder: (context, request) =>
          TextFormField(initialValue: request.toolCallId),
    );

    expect(find.text('call-1'), findsOneWidget);
    expect(find.text('Empties the list.'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    // The card of the next call takes the place of this one in the list.
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(find.text('call-2'), findsOneWidget);
  });
}

/// Shows a chat whose agent plays [turns] on a new session about the list
/// `['x']`, sends `clear`, and returns the shop once the first run is done.
Future<Shop> _sendClear(
  WidgetTester tester,
  List<AgentTurn> turns, {
  ApprovalBuilder? approvalBuilder,
}) async {
  final shop = Shop()..add('x');
  addTearDown(shop.close);
  final session = TandemSession(
    surface: shop,
    changes: shop.changes,
    connection: ScriptedAgent(turns),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: TandemSessionScope(
        session: session,
        child: TandemChat(approvalBuilder: approvalBuilder),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), 'clear');
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
  return shop;
}
