import 'package:example/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem_bloc/tandem_bloc.dart';
import 'package:tandem_bloc/testing.dart';

final class const _Screen({
  required final ShoppingListCubit cubit,
  required final AgentConnection agent,
  final void Function(BuildContext context, AgentCall call)? onAgentCall,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: TandemScope<ShoppingListCubit>.connected(
        connection: agent,
        onAgentCall: onAgentCall,
        child: const TandemChat(),
      ),
    ),
  );
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the agent adds an item through the same method as the app', (
    tester,
  ) async {
    final calls = <(AgentCall, ShoppingListCubit)>[];
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
            onAgentCall: (context, call) =>
                calls.add((call, context.read<ShoppingListCubit>())),
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

    await _send(tester, 'milk please');

    final cubit = tester
        .element(find.byType(TandemChat))
        .read<ShoppingListCubit>();
    expect(cubit.items, ['milk']);
    expect(find.text('Added milk.'), findsOneWidget);
    // The listener's context is below the provider: it reads the cubit.
    final [(AgentCall(:tool, :arguments, :result), heardBy)] = calls;
    expect((tool, result, heardBy), ('add', null, cubit));
    expect(arguments, {'item': 'milk'});
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
    await tester.pumpWidget(_Screen(cubit: first, agent: agent));
    await tester.pumpWidget(_Screen(cubit: second, agent: agent));

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
      _Screen(
        cubit: cubit,
        agent: agent,
        onAgentCall: (context, _) => heard.add('first'),
      ),
    );
    await _send(tester, 'milk please');
    await tester.pumpWidget(
      _Screen(
        cubit: cubit,
        agent: agent,
        onAgentCall: (context, _) => heard.add('second'),
      ),
    );
    await _send(tester, 'and bread');

    expect(heard, ['first', 'second']);
    expect(cubit.items, ['milk', 'bread']);
    expect(find.text('Added milk.'), findsOneWidget); // The chat went on.
  });
}
