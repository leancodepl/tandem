import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/shop.dart';

void main() {
  // In the test, so that its futures and stream belong to the fake zone.
  Shop newShop() {
    final shop = Shop()..items.add('milk');
    addTearDown(shop.close);
    return shop;
  }

  TandemSession sessionOf(WidgetTester tester) =>
      TandemSessionScope.of(tester.element(find.byKey(_below)));

  Future<void> ask(WidgetTester tester, String text) async {
    sessionOf(tester).send(text);
    await tester.pumpAndSettle();
  }

  testWidgets('a run offers show_view only while a TandemView is below the '
      'scope', (tester) async {
    final shop = newShop();
    final agent = ScriptedAgent([_say, _say]);
    await tester.pumpWidget(_app(shop, agent, withView: false));
    await ask(tester, 'hi');
    await tester.pumpWidget(_app(shop, agent));
    await ask(tester, 'hi');

    expect(
      [for (final request in agent.requests) _toolNames(request)],
      [
        isNot(contains('show_view')),
        ['add', 'remove_at', 'refresh', 'clear', 'share', 'show_view'],
      ],
    );
  });

  testWidgets('show_view draws the view, and the next run says it shows', (
    tester,
  ) async {
    final agent = ScriptedAgent([_show(_firstItem), _say]);
    await tester.pumpWidget(_app(newShop(), agent));
    await ask(tester, 'show the list');

    expect(find.text('milk'), findsOneWidget);
    expect(_answers(agent.requests.last), ['{"status":"shown"}']);
  });

  testWidgets('show_view that does not fit the screen is refused, and the '
      'view stays', (tester) async {
    final agent = ScriptedAgent([
      _show(_firstItem),
      _say,
      _show([
        {
          'id': 'root',
          'component': 'Text',
          'text': {'path': '/basket'},
        },
      ]),
      _say,
    ]);
    await tester.pumpWidget(_app(newShop(), agent));
    await ask(tester, 'show the list');
    await ask(tester, 'show the basket');

    expect(find.text('milk'), findsOneWidget);
    expect(
      _answers(agent.requests.last).last,
      allOf(contains('refused'), contains('/basket')),
    );
  });

  testWidgets('the view follows what the screen lists with .sees', (
    tester,
  ) async {
    final shop = newShop();
    await tester.pumpWidget(
      _app(shop, ScriptedAgent([_show(_firstItem), _say])),
    );
    await ask(tester, 'show the list');

    shop
      ..removeAt(0)
      ..add('eggs');
    await tester.pumpAndSettle();

    expect(find.text('eggs'), findsOneWidget);
  });

  testWidgets('without the view, the next run offers no show_view, and a '
      'call of an open run is refused', (tester) async {
    final shop = newShop();
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (request) => [
        ..._show(_firstItem)(request),
        AgentStep.waitFor(gate.future),
      ],
      _say,
    ]);
    await tester.pumpWidget(_app(shop, agent));
    sessionOf(tester).send('show the list');
    await tester.pump();
    await tester.pumpWidget(_app(shop, agent, withView: false));
    gate.complete();
    await tester.pumpAndSettle();

    expect(_toolNames(agent.requests.last), isNot(contains('show_view')));
    expect(_answers(agent.requests.last), [
      contains('No view is on the screen now.'),
    ]);
  });

  testWidgets('a new session of the scope starts with an empty view', (
    tester,
  ) async {
    final shop = newShop();
    await tester.pumpWidget(
      _app(shop, ScriptedAgent([_show(_firstItem), _say])),
    );
    await ask(tester, 'show the list');
    await tester.pumpWidget(_app(shop, ScriptedAgent([])));

    expect(find.text('milk'), findsNothing);
  });
}

const _below = Key('below');

Widget _app(Shop shop, AgentConnection agent, {bool withView = true}) =>
    MaterialApp(
      home: Scaffold(
        body: TandemScope.connected(
          surface: (context) => shop,
          connection: agent,
          approvals: const .fromState(),
          child: Column(
            children: [
              if (withView) const Expanded(child: TandemView()),
              const SizedBox(key: _below),
            ],
          ),
        ),
      ),
    );

List<AgentStep> _say(Map<String, Object?> request) => const [
  AgentStep.say('Done.'),
];

AgentTurn _show(List<Map<String, Object?>> components) =>
    (request) => [
      AgentStep.callTool('show_view', {
        'messages': [
          {
            'version': 'v0.9.1',
            'createSurface': {
              'surfaceId': 'main',
              'catalogId': tandemCatalogId,
            },
          },
          {
            'version': 'v0.9.1',
            'updateComponents': {'surfaceId': 'main', 'components': components},
          },
        ],
      }),
    ];

const _firstItem = [
  {
    'id': 'root',
    'component': 'Text',
    'text': {'path': '/items/0'},
  },
];

List<Object?> _toolNames(Map<String, Object?> request) => [
  if (request case {'tools': final List<Object?> tools})
    for (final tool in tools)
      if (tool case {'name': final name}) name,
];

/// The contents of the tool messages that answer calls in [request].
List<Object?> _answers(Map<String, Object?> request) => [
  if (request case {'messages': final List<Object?> messages})
    for (final message in messages)
      if (message case {'role': 'tool', 'content': final content}) content,
];
