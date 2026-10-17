import 'package:example/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

Widget _screen(
  ShoppingListCubit cubit,
  AgentConnection agent, {
  AgentCallListener? onAgentCall,
}) => MaterialApp(
  home: BlocProvider.value(
    value: cubit,
    child: TandemScope<ShoppingListCubit>.connected(
      connection: agent,
      onAgentCall: onAgentCall,
      child: const TandemChat(),
    ),
  ),
);

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
}

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

  testWidgets('the agent follows the cubit the provider gives now', (
    tester,
  ) async {
    final first = ShoppingListCubit();
    final second = ShoppingListCubit();
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Added milk.')],
    ]);
    await tester.pumpWidget(_screen(first, agent));
    await tester.pumpWidget(_screen(second, agent));

    await _send(tester, 'milk please');

    expect(first.items, isEmpty);
    expect(second.items, ['milk']);
  });

  testWidgets('a rebuilt scope calls the listener it has now', (tester) async {
    final cubit = ShoppingListCubit();
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Added milk.')],
      (_) => const [
        AgentStep.callTool('add', {'item': 'bread'}),
      ],
      (_) => const [AgentStep.say('Added bread.')],
    ]);
    final heard = <String>[];
    await tester.pumpWidget(
      _screen(
        cubit,
        agent,
        onAgentCall: (tool, arguments, result) => heard.add('first'),
      ),
    );
    await _send(tester, 'milk please');
    await tester.pumpWidget(
      _screen(
        cubit,
        agent,
        onAgentCall: (tool, arguments, result) => heard.add('second'),
      ),
    );
    await _send(tester, 'and bread');

    expect(heard, ['first', 'second']);
    expect(cubit.items, ['milk', 'bread']);
    expect(find.text('Added milk.'), findsOneWidget); // The chat went on.
  });
}
