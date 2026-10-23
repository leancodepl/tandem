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

  Future<ScriptedAgent> drawButtons(
    WidgetTester tester,
    Shop shop, {
    List<AgentTurn> later = const [],
    TandemApprovals approvals = const .fromState(),
    void Function(BuildContext, TandemEvent, TandemSession)? onEvent,
  }) async {
    final agent = ScriptedAgent([_show(_buttons), _say, ...later]);
    await tester.pumpWidget(
      _app(shop, agent, approvals: approvals, onEvent: onEvent),
    );
    await ask(tester, 'show buttons');
    return agent;
  }

  ApprovalRequest lastRequest(WidgetTester tester) =>
      sessionOf(tester).items.whereType<ApprovalRequest>().last;

  testWidgets('a button calls its method, onEvent hears it, and the agent '
      'gets no call', (tester) async {
    final shop = newShop();
    final events = <TandemEvent>[];
    final agent = await drawButtons(
      tester,
      shop,
      later: [_say],
      onEvent: (context, event, _) => events.add(event),
    );

    await tester.tap(find.text('Add eggs'));
    await tester.pumpAndSettle();
    await ask(tester, 'hi');

    expect(shop.items, ['milk', 'eggs']);
    expect(
      events.single,
      isA<AgentCall>().having((c) => c.tool, 'tool', 'add'),
    );
    expect(_toolCallNames(agent), isNot(contains('add')));
  });

  testWidgets('the agent learns what a button did with the next message', (
    tester,
  ) async {
    final shop = newShop();
    final agent = await drawButtons(tester, shop, later: [_say]);

    await tester.tap(find.text('Add eggs'));
    await tester.pumpAndSettle();
    await ask(tester, 'did it work?');

    // One message: ag-ui-adk passes on only the last user message of a run.
    expect(_userTexts(agent.requests.last), [
      'show buttons',
      allOf(
        startsWith('The user pressed a button in your view. It called add '),
        contains('{"item":"eggs"}'),
        endsWith('\n\ndid it work?'),
      ),
    ]);
  });

  testWidgets('a button of a method with approval asks the user, and Approve '
      'runs it', (tester) async {
    final shop = newShop();
    await drawButtons(tester, shop);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    final request = lastRequest(tester);
    expect(request.tool, 'clear');
    expect(sessionOf(tester).status, AwaitingApproval(request));
    sessionOf(tester).approve(request);
    await tester.pumpAndSettle();

    expect(shop.items, isEmpty);
  });

  testWidgets('Reject keeps the method from running, and the agent learns '
      'nothing of it', (tester) async {
    final shop = newShop();
    final agent = await drawButtons(tester, shop, later: [_say]);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    sessionOf(tester).reject(lastRequest(tester));
    await tester.pumpAndSettle();
    await ask(tester, 'hi');

    expect(lastRequest(tester).status, ApprovalStatus.rejected);
    expect(shop.items, ['milk']);
    expect(_userTexts(agent.requests.last), ['show buttons', 'hi']);
  });

  testWidgets('a change to .sees invalidates the request of a button', (
    tester,
  ) async {
    final shop = newShop();
    await drawButtons(tester, shop);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    shop.add('eggs');
    await tester.pumpAndSettle();

    expect(lastRequest(tester).status, ApprovalStatus.invalidated);
    expect(shop.items, ['milk', 'eggs']);
  });

  testWidgets('a button with approval is off while the session is not idle', (
    tester,
  ) async {
    final shop = newShop();
    final gate = Completer<void>();
    await drawButtons(
      tester,
      shop,
      later: [
        (_) => [AgentStep.waitFor(gate.future)],
      ],
    );

    sessionOf(tester).send('think');
    await tester.pump();
    final whileThinking = _onPressed(tester, 'Clear');
    final callsWhileThinking = _onPressed(tester, 'Add eggs');
    gate.complete();
    await tester.pumpAndSettle();

    expect(whileThinking, isNull);
    expect(callsWhileThinking, isNotNull);
    expect(_onPressed(tester, 'Clear'), isNotNull);
  });

  testWidgets('a button is off when its method is not listed now, and with '
      'approval on a screen that never asks', (tester) async {
    final shop = newShop();
    await drawButtons(tester, shop, approvals: const .none());

    shop.removeAt(0);
    await tester.pumpAndSettle();

    expect(_onPressed(tester, 'Clear'), isNull);
    expect(_onPressed(tester, 'Share'), isNull);
    expect(_onPressed(tester, 'Add eggs'), isNotNull);
  });

  testWidgets('a message of the user cancels the request of a button', (
    tester,
  ) async {
    final shop = newShop();
    await drawButtons(tester, shop, later: [_say]);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    await ask(tester, 'no, wait');

    expect(lastRequest(tester).status, ApprovalStatus.cancelled);
    expect(shop.items, ['milk']);
  });

  testWidgets('a request of the coding agent waits for the request of a '
      'button and shows after it', (tester) async {
    final shop = newShop();
    await drawButtons(tester, shop);

    await tester.tap(find.text('Share'));
    await tester.pump();
    final click = lastRequest(tester);
    final coding = TandemBridge.call('clear');
    expect(lastRequest(tester), same(click));
    sessionOf(tester).approve(click);
    await tester.pumpAndSettle();
    sessionOf(tester).approve(lastRequest(tester));

    expect(await coding, containsPair('status', 'returned'));
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

Widget _app(
  Shop shop,
  AgentConnection agent, {
  bool withView = true,
  TandemApprovals approvals = const .fromState(),
  void Function(BuildContext, TandemEvent, TandemSession)? onEvent,
}) => MaterialApp(
  home: Scaffold(
    body: TandemScope.connected(
      surface: (context) => shop,
      connection: agent,
      approvals: approvals,
      onEvent: onEvent,
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

/// The first item, and a button for each of `add`, `clear` and `share`.
final _buttons = [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['first', 'add', 'clear', 'share'],
  },
  ..._firstItem.map((text) => {...text, 'id': 'first'}),
  for (final (id, label, context) in [
    ('add', 'Add eggs', {'item': 'eggs'}),
    ('clear', 'Clear', <String, Object?>{}),
    ('share', 'Share', <String, Object?>{}),
  ]) ...[
    {
      'id': id,
      'component': 'Button',
      'child': '${id}_label',
      'action': {
        'event': {'name': id, 'context': context},
      },
    },
    {'id': '${id}_label', 'component': 'Text', 'text': label},
  ],
];

VoidCallback? _onPressed(WidgetTester tester, String label) => tester
    .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
    .onPressed;

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

/// The contents of the user messages in [request].
List<Object?> _userTexts(Map<String, Object?> request) => [
  if (request case {'messages': final List<Object?> messages})
    for (final message in messages)
      if (message case {'role': 'user', 'content': final content}) content,
];

/// The names of the calls the agent made in the messages of its last run.
List<Object?> _toolCallNames(ScriptedAgent agent) => [
  if (agent.requests.last case {'messages': final List<Object?> messages})
    for (final message in messages)
      if (message case {'toolCalls': final List<Object?> calls})
        for (final call in calls)
          if (call case {'function': {'name': final name}}) name,
];
