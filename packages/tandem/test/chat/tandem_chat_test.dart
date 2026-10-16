import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

import '../support/shop.dart';

void main() {
  testWidgets("shows the agent's text and an approval card it can approve", (
    tester,
  ) async {
    final shop = await _askToClear(tester);

    expect(find.text('Clear the list?'), findsOneWidget);
    expect(find.text('Empties the list.'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Cleared.'), findsOneWidget);
    expect(shop.items, isEmpty);

    await _askToClear(
      tester,
      approvalBuilder: (context, request) => Text('Custom ${request.tool}'),
    );

    expect(find.text('Custom clear'), findsOneWidget);
    expect(find.text('Empties the list.'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });
}

/// Shows a chat on a new session, writes `clear`, and returns the shop once
/// the agent asked to clear it.
Future<Shop> _askToClear(
  WidgetTester tester, {
  ApprovalBuilder? approvalBuilder,
}) async {
  final shop = Shop()..add('x');
  final session = TandemSession(
    surface: shop,
    changes: shop.changes,
    connection: ScriptedAgent([
      (_) => const [
        AgentStep.say('Clear the list?'),
        AgentStep.callTool('clear'),
      ],
      (_) => const [AgentStep.say('Cleared.')],
    ]),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: TandemSessionScope(
        session: session,
        child: Row(
          children: [
            const Expanded(child: SizedBox()),
            TandemChat(approvalBuilder: approvalBuilder),
          ],
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), 'clear');
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
  return shop;
}
