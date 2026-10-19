import 'dart:async';

import 'package:example/agent_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'shopping_list.dart';

void main() {
  testWidgets("shows the agent's text and a default card it can approve", (
    tester,
  ) async {
    final list = await _sendClear(tester, [
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
    expect(list.items, isEmpty);
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

    // The next card lands at this index, so it needs a state of its own.
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(find.text('call-2'), findsOneWidget);
  });

  testWidgets('a scrolled-up chat jumps only to show a new card', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 320)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final more = Completer<void>();
    final card = Completer<void>();
    await _sendClear(tester, [
      (_) => [
        for (var index = 0; index < 20; index++) AgentStep.say('Update $index'),
        AgentStep.waitFor(more.future),
        const AgentStep.say('One more update'),
        AgentStep.waitFor(card.future),
        const AgentStep.callTool('clear'),
      ],
    ]);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    final readerAt = _chatOffset(tester);

    more.complete();
    await tester.pumpAndSettle();
    expect(_chatOffset(tester), readerAt);

    card.complete();
    await tester.pumpAndSettle();
    expect(find.text('Approve').hitTestable(), findsOneWidget);
  });

  testWidgets('Stop is disabled while an approved method runs', (tester) async {
    final list = await _sendClear(tester, [
      (_) => const [AgentStep.callTool('clear')],
    ]);
    list.serverReply = Completer<void>().future;

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    final stop = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Stop'),
    );
    expect(stop.onPressed, isNull);
  });
}

Future<ShoppingListCubit> _sendClear(
  WidgetTester tester,
  List<AgentTurn> turns, {
  ApprovalBuilder? approvalBuilder,
}) async {
  final list = ShoppingListCubit()..add('x');
  addTearDown(list.close);
  await tester.pumpWidget(
    MaterialApp(
      home: TandemScope.connected(
        surface: (context) => list,
        connection: ScriptedAgent(turns),
        approvals: const .fromState(),
        child: AgentChat(approvalBuilder: approvalBuilder),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), 'clear');
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
  return list;
}

double? _chatOffset(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).controller?.offset;
