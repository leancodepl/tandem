import 'dart:async';

import 'package:example/agent_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/tandem_bloc.dart';
import 'package:tandem_bloc/testing.dart';

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
      home: BlocProvider.value(
        value: list,
        child: TandemScope<ShoppingListCubit>.connected(
          connection: ScriptedAgent(turns),
          child: AgentChat(approvalBuilder: approvalBuilder),
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), 'clear');
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
  return list;
}
