import 'package:example/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

void main() {
  testWidgets('the agent adds an item through the same method as the app', (
    tester,
  ) async {
    final calls = <List<Object?>>[];
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Added milk.')],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (context) => ShoppingListCubit(),
          child: TandemScope<ShoppingListCubit>.connected(
            connection: agent,
            onAgentCall: (tool, arguments, result) =>
                calls.add([tool, arguments, result]),
            child: const Row(
              children: [
                Expanded(child: SizedBox()),
                SizedBox(width: 360, child: TandemChat()),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'milk please');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final cubit = tester
        .element(find.byType(TandemChat))
        .read<ShoppingListCubit>();
    expect(cubit.items, ['milk']);
    expect(find.text('Added milk.'), findsOneWidget);
    expect(calls, [
      [
        'add',
        {'item': 'milk'},
        null,
      ],
    ]);
    expect(agent.requests[0]['context'], [
      {
        'description': 'items: What is on the shopping list now.',
        'value': '[]',
      },
    ]);
  });
}
