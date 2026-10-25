import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/shop.dart';
import '../support/views.dart';

void main() {
  late Shop shop;

  Widget screen(AgentConnection agent, {Widget view = const TandemView()}) =>
      MaterialApp(
        home: Scaffold(
          body: TandemScope.connected(
            surface: (context) => shop,
            connection: agent,
            approvals: const .fromState(),
            child: Column(children: [view, const _Chat()]),
          ),
        ),
      );

  TandemSession sessionOf(WidgetTester tester) =>
      TandemSessionScope.of(tester.element(find.byType(_Chat)));

  AgentStep show(List<Map<String, Object?>> messages) =>
      AgentStep.callTool('tandem_show_view', {'messages': messages});

  testWidgets('a run offers tandem_show_view after the listed methods only '
      'while a TandemView is on the screen', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Hi again.')],
    ]);
    await tester.pumpWidget(screen(agent, view: const SizedBox()));
    sessionOf(tester).send('hi');
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('hi again');
    await tester.pumpAndSettle();

    expect(
      [for (final request in agent.requests) _toolNames(request)],
      [
        ['add', 'remove_at', 'refresh', 'clear', 'share'],
        ['add', 'remove_at', 'refresh', 'clear', 'share', 'tandem_show_view'],
      ],
    );
  });

  testWidgets('a view the agent sends shows what .sees lists, follows it, and '
      'the next run hears that it shows', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();

    expect(find.text('First: milk'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(_lastAnswer(agent.requests[1]), {'status': 'shown'});

    shop.add('eggs');
    await tester.pumpAndSettle();
    expect(find.text('eggs'), findsOneWidget);
  });

  testWidgets('a view that does not fit is refused with what to fix, and the '
      'last view stays', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
      (_) => [
        show(
          drawing([
            {
              'id': 'root',
              'component': 'Column',
              'children': ['empty'],
            },
            ...button('empty', {'name': 'empty_the_list'}),
          ]),
        ),
      ],
      (_) => const [AgentStep.say('I cannot.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();
    sessionOf(tester).send('add a button to empty it');
    await tester.pumpAndSettle();

    expect(_lastAnswer(agent.requests[3]), {
      'status': 'refused',
      'reason': startsWith('empty must call a method of the screen'),
    });
    expect(find.text('First: milk'), findsOneWidget);
  });

  testWidgets('a new view replaces the whole last one', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
      (_) => [
        show(
          drawing([
            {'id': 'root', 'component': 'Text', 'text': 'Just a text'},
          ]),
        ),
      ],
      (_) => const [AgentStep.say('Simpler now.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();
    sessionOf(tester).send('make it simpler');
    await tester.pumpAndSettle();

    expect(find.text('Just a text'), findsOneWidget);
    expect(find.text('bread'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status says the agent draws from the start of '
      'tandem_show_view until its next text', (tester) async {
    shop = _newShop();
    final stream = StreamController<Map<String, Object?>>();
    addTearDown(stream.close);
    await tester.pumpWidget(screen(_FirstRun(stream.stream)));
    sessionOf(tester).send('show my list');

    stream.add({
      'type': 'TOOL_CALL_START',
      'toolCallId': 'c1',
      'toolCallName': 'tandem_show_view',
    });
    await tester.pump();
    expect(sessionOf(tester).status, const Thinking(drawing: true));
    stream.add({
      'type': 'TEXT_MESSAGE_CONTENT',
      'messageId': 'm1',
      'delta': 'Here.',
    });
    await tester.pump();
    expect(sessionOf(tester).status, const Thinking());
  });

  testWidgets('once the TandemView is gone, a call of the open run is refused '
      'and the next run no longer offers tandem_show_view', (tester) async {
    shop = _newShop();
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(gate.future), show(shoppingListView)],
      (_) => const [AgentStep.say('It is gone.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pump();
    await tester.pumpWidget(screen(agent, view: const SizedBox()));
    gate.complete();
    await tester.pumpAndSettle();

    expect(_lastAnswer(agent.requests[1]), {
      'status': 'refused',
      'reason': 'No view is on the screen now.',
    });
    expect(_toolNames(agent.requests[1]), isNot(contains('tandem_show_view')));
  });

  testWidgets('a new session of the scope starts with an empty view', (
    tester,
  ) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();
    expect(find.text('bread'), findsOneWidget);

    await tester.pumpWidget(screen(ScriptedAgent([])));

    expect(find.text('bread'), findsNothing);
  });
}

/// Stands for the app's chat, to find the session by.
final class const _Chat() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Streams [_first] as its only run.
final class _FirstRun(final Stream<Map<String, Object?>> _first)
    implements AgentConnection {
  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) => _first;
}

List<Object?> _toolNames(Map<String, Object?> request) => switch (request) {
  {'tools': final List<Object?> tools} => [
    for (final tool in tools)
      if (tool case {'name': final name}) name,
  ],
  _ => const [],
};

/// The decoded answer of the last tool message of [request].
Object? _lastAnswer(Map<String, Object?> request) {
  final {'messages': messages as List<Object?>} = request;
  final answers = [
    for (final message in messages)
      if (message case {'role': 'tool', 'content': final String content})
        content,
  ];
  return jsonDecode(answers.last);
}

/// Called in each test, so that the shop's futures and stream belong to the
/// fake zone.
Shop _newShop() {
  final shop = Shop()..items.addAll(['milk', 'bread']);
  addTearDown(shop.close);
  return shop;
}
