import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/shop.dart';

void main() {
  // In the test, so that its futures and stream belong to the fake zone.
  Shop newShop() {
    final shop = Shop();
    addTearDown(shop.close);
    return shop;
  }

  Widget scope(
    Shop shop, {
    TandemApprovals approvals = const .fromState(),
    void Function(BuildContext, TandemEvent, TandemSession)? onEvent,
  }) => TandemScope(
    surface: (context) => shop,
    approvals: approvals,
    onEvent: onEvent,
    child: const SizedBox(),
  );

  Widget connected(Shop shop, AgentConnection connection) =>
      TandemScope.connected(
        surface: (context) => shop,
        connection: connection,
        approvals: const .fromState(),
        child: const SizedBox(),
      );

  TandemSession sessionOf(WidgetTester tester) =>
      TandemSessionScope.of(tester.element(find.byType(SizedBox)));

  ApprovalRequest lastRequest(WidgetTester tester) =>
      sessionOf(tester).items.whereType<ApprovalRequest>().last;

  testWidgets('describe lists the open screens with what the agent sees, '
      'its tools and which need approval', (tester) async {
    final shop = newShop();
    shop.items.add('milk');
    await tester.pumpWidget(scope(shop));

    final {'screens': screens as List<Object?>} = TandemBridge.describe();

    expect(screens.single, {
      'id': 'Shop',
      'front': true,
      'sees': [
        {
          'description': 'items: What is on the shopping list now.',
          'value': '["milk"]',
        },
      ],
      'tools': [
        for (final name in ['add', 'remove_at', 'refresh', 'clear', 'share'])
          containsPair('name', name),
      ],
      'needsApproval': ['clear', 'share'],
    });
  });

  testWidgets('a route pushed over a screen is in front, and after pop the '
      'screen below it', (tester) async {
    final shop = newShop();
    final above = newShop();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Navigator(
          key: navigator,
          onGenerateRoute: (_) => _route(scope(shop)),
        ),
      ),
    );

    navigator.currentState?.push(_route(scope(above)));
    await tester.pumpAndSettle();
    await TandemBridge.call('add', arguments: {'item': 'tea'});
    navigator.currentState?.pop();
    await tester.pumpAndSettle();
    await TandemBridge.call('add', arguments: {'item': 'milk'});

    expect(above.items, ['tea']);
    expect(shop.items, ['milk']);
  });

  testWidgets('with two screens on one route, a call names its screen', (
    tester,
  ) async {
    final shop = newShop();
    final other = newShop();
    await tester.pumpWidget(Column(children: [scope(shop), scope(other)]));

    final refused = await TandemBridge.call('add', arguments: {'item': 'x'});
    await TandemBridge.call('add', arguments: {'item': 'y'}, screen: 'Shop#2');

    expect(refused, containsPair('status', 'refused'));
    expect(refused, containsPair('reason', contains('Shop, Shop#2')));
    expect(shop.items, isEmpty);
    expect(other.items, ['y']);
  });

  testWidgets('a call returns the result and the screens after it, and '
      'onEvent hears it from the coding agent', (tester) async {
    final shop = newShop();
    final events = <TandemEvent>[];
    await tester.pumpWidget(
      scope(shop, onEvent: (context, event, _) => events.add(event)),
    );

    final answer = await TandemBridge.call('add', arguments: {'item': 'milk'});

    expect(answer, {
      'status': 'returned',
      'result': null,
      'screens': [
        containsPair('sees', [containsPair('value', '["milk"]')]),
      ],
    });
    expect(events, [
      isA<AgentCall>()
          .having((call) => call.tool, 'tool', 'add')
          .having((call) => call.arguments, 'arguments', {'item': 'milk'})
          .having((call) => call.caller, 'caller', Caller.codingAgent),
    ]);
  });

  testWidgets('a method not listed now, arguments of the wrong type and an '
      'unknown key are refused, and the method does not run', (tester) async {
    final shop = newShop();
    await tester.pumpWidget(scope(shop));

    final answers = [
      await TandemBridge.call('clear'),
      await TandemBridge.call('add', arguments: {'item': 3}),
      await TandemBridge.call('add', arguments: {'item': 'x', 'size': 2}),
    ];

    expect(answers, everyElement(containsPair('status', 'refused')));
    expect(
      [for (final answer in answers) answer['reason']],
      [
        'The agent cannot call clear now.',
        contains('item'),
        contains('size: unknown'),
      ],
    );
    expect(shop.items, isEmpty);
  });

  testWidgets('a call that needs approval shows as AwaitingApproval, and '
      'Approve returns its result', (tester) async {
    final shop = newShop();
    await tester.pumpWidget(scope(shop));

    final answer = TandemBridge.call('share');
    final request = lastRequest(tester);
    expect(sessionOf(tester).status, AwaitingApproval(request));
    expect(request.caller, Caller.codingAgent);
    sessionOf(tester).approve(request);

    expect(await answer, containsPair('status', 'returned'));
    expect(sessionOf(tester).status, isA<Idle>());
  });

  testWidgets('Reject answers rejected_by_user', (tester) async {
    final shop = newShop();
    await tester.pumpWidget(scope(shop));

    final answer = TandemBridge.call('share');
    sessionOf(tester).reject(lastRequest(tester));

    expect(await answer, containsPair('status', 'rejected_by_user'));
  });

  testWidgets('a change to .sees while the request shows invalidates it', (
    tester,
  ) async {
    final shop = newShop();
    await tester.pumpWidget(scope(shop));

    final answer = TandemBridge.call('share');
    shop.add('milk');
    await tester.pump();

    expect(await answer, containsPair('status', 'invalidated'));
    expect(lastRequest(tester).status, ApprovalStatus.invalidated);
  });

  testWidgets('the approval callback gets the request', (tester) async {
    final shop = newShop();
    final asked = <String>[];
    await tester.pumpWidget(
      scope(
        shop,
        approvals: .callback((context, request, session) async {
          asked.add(request.tool);
          session.approve(request);
        }),
      ),
    );

    final answer = await TandemBridge.call('share');

    expect(answer, containsPair('status', 'returned'));
    expect(asked, ['share']);
  });

  testWidgets('a screen that takes no approvals refuses the call, and '
      'autoApprove runs it without a request', (tester) async {
    final shop = newShop();
    addTearDown(TandemBridge.enable);
    await tester.pumpWidget(scope(shop, approvals: const .none()));

    final refused = await TandemBridge.call('share');
    TandemBridge.enable(autoApprove: true);
    final approved = await TandemBridge.call('share');

    expect(refused, containsPair('reason', contains('autoApprove')));
    expect(approved, containsPair('status', 'returned'));
    expect(sessionOf(tester).items, isEmpty);
  });

  testWidgets('the same call joins the waiting request, and another one is '
      'refused', (tester) async {
    final shop = newShop();
    shop.items.add('milk');
    await tester.pumpWidget(scope(shop));

    final first = TandemBridge.call('share');
    final again = TandemBridge.call('share');
    final other = await TandemBridge.call('clear');
    sessionOf(tester).approve(lastRequest(tester));

    expect(await first, containsPair('status', 'returned'));
    expect(await again, containsPair('status', 'returned'));
    expect(other, containsPair('status', 'refused'));
    expect(sessionOf(tester).items.whereType<ApprovalRequest>(), hasLength(1));
    expect(shop.items, ['milk']);
  });

  testWidgets('a request of the coding agent waits while one of the in-app '
      'agent shows, and no call of the bridge reaches the agent', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Shared.')],
    ]);
    await tester.pumpWidget(connected(newShop(), agent));
    await TandemBridge.call('add', arguments: {'item': 'milk'});
    sessionOf(tester).send('share it');
    await tester.pumpAndSettle();
    final inApp = lastRequest(tester);

    final answer = TandemBridge.call('share');
    expect(lastRequest(tester), same(inApp));
    sessionOf(tester).approve(inApp);
    await tester.pumpAndSettle();
    final codingAgents = lastRequest(tester);
    sessionOf(tester).approve(codingAgents);

    expect(await answer, containsPair('status', 'returned'));
    expect(agent.requests, hasLength(2));
    expect(
      jsonEncode([for (final request in agent.requests) request['messages']]),
      isNot(anyOf(contains('"add"'), contains(codingAgents.toolCallId))),
    );
  });

  testWidgets("a decision on the coding agent's request sends no answers of "
      'the in-app agent, also after a stopped turn that has them all', (
    tester,
  ) async {
    final shop = newShop();
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('refresh')],
    ]);
    await tester.pumpWidget(connected(shop, agent));
    sessionOf(tester).send('refresh');
    await tester.pump();
    expect(sessionOf(tester).status, const Calling('refresh', approved: false));
    sessionOf(tester).stop();
    serverReply.complete();
    await tester.pumpAndSettle();
    expect(shop.refreshes, 1);

    final answer = TandemBridge.call('share');
    sessionOf(tester).approve(lastRequest(tester));

    expect(await answer, containsPair('status', 'returned'));
    expect(agent.requests, hasLength(1));
  });

  testWidgets('a request of the coding agent shows once a run of the in-app '
      'agent breaks', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(connected(newShop(), _Interrupted(gate.future)));
    sessionOf(tester).send('hi');

    final answer = TandemBridge.call('share');
    gate.complete();
    await tester.pump();
    expect(tester.takeException(), isA<AgentRunException>());
    sessionOf(tester).approve(lastRequest(tester));

    expect(await answer, containsPair('status', 'returned'));
  });

  testWidgets('a request of the coding agent shows once a change to .sees '
      'invalidates the request of the in-app agent', (tester) async {
    final shop = newShop();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share')],
    ]);
    await tester.pumpWidget(connected(shop, agent));
    sessionOf(tester).send('share it');
    await tester.pumpAndSettle();
    final changesArrive = Completer<void>();
    shop
      ..changesArrive = changesArrive.future
      ..add('milk');

    unawaited(TandemBridge.call('clear'));
    changesArrive.complete();
    await tester.pump();

    expect(lastRequest(tester).tool, 'clear');
    expect(sessionOf(tester).status, AwaitingApproval(lastRequest(tester)));
  });

  testWidgets('a request of the coding agent waits for the run that takes '
      'the answers of an approved method', (tester) async {
    final shop = newShop();
    final serverReply = Completer<void>();
    // No change reaches the session: only Approve and the end of the
    // approved method compare .sees.
    shop
      ..serverReply = serverReply.future
      ..changesArrive = Completer<void>().future;
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
      (_) => [AgentStep.waitFor(gate.future), const AgentStep.say('Shared.')],
    ]);
    await tester.pumpWidget(connected(shop, agent));
    sessionOf(tester).send('share it twice');
    await tester.pumpAndSettle();
    sessionOf(tester).approve(lastRequest(tester));
    await TandemBridge.call('add', arguments: {'item': 'milk'});
    final answer = TandemBridge.call('clear');
    serverReply.complete();
    await tester.pump();

    expect(sessionOf(tester).status, isA<Thinking>());
    expect(lastRequest(tester).tool, 'share');

    gate.complete();
    await tester.pumpAndSettle();
    expect(lastRequest(tester).tool, 'clear');
    sessionOf(tester).approve(lastRequest(tester));
    expect(await answer, containsPair('status', 'returned'));
    expect(
      sessionOf(tester).items.whereType<AgentMessage>().single.text,
      'Shared.',
    );
  });

  testWidgets('a message of the user cancels the request that shows', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi')],
    ]);
    await tester.pumpWidget(connected(newShop(), agent));

    final answer = TandemBridge.call('share');
    sessionOf(tester).send('hi');
    await tester.pumpAndSettle();

    expect(await answer, containsPair('status', 'cancelled'));
    expect(lastRequest(tester).status, ApprovalStatus.cancelled);
    expect(
      jsonEncode(agent.requests.single['messages']),
      isNot(contains('share')),
    );
  });

  testWidgets('closing the screen cancels the request that waits', (
    tester,
  ) async {
    final shop = newShop();
    await tester.pumpWidget(scope(shop));

    final answer = TandemBridge.call('share');
    await tester.pumpWidget(const SizedBox());

    expect(await answer, {'status': 'cancelled', 'screens': <Object?>[]});
  });

  testWidgets('enable twice does not throw, and the last autoApprove holds', (
    tester,
  ) async {
    final shop = newShop();
    addTearDown(TandemBridge.enable);
    TandemBridge.enable(autoApprove: true);
    TandemBridge.enable();
    await tester.pumpWidget(scope(shop));

    unawaited(TandemBridge.call('share'));
    await tester.pump();

    expect(sessionOf(tester).status, isA<AwaitingApproval>());
  });

  testWidgets('once the user decided, describe shows the last approval with '
      'its answer', (tester) async {
    final shop = newShop();
    await tester.pumpWidget(scope(shop));

    // The coding agent stopped waiting, as after a timeout of its client.
    unawaited(TandemBridge.call('share'));
    sessionOf(tester).approve(lastRequest(tester));
    await tester.pump();

    final {'screens': screens as List<Object?>} = TandemBridge.describe();
    expect(
      screens.single,
      containsPair('lastApproval', {
        'tool': 'share',
        'arguments': <String, Object?>{},
        'status': 'returned',
        'result': null,
      }),
    );
  });
}

/// Ends its run with an interrupt, which Tandem cannot follow, once [_gate]
/// completes.
final class _Interrupted(final Future<void> _gate) implements AgentConnection {
  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) async* {
    await _gate;
    yield {
      'type': 'RUN_FINISHED',
      'outcome': {'type': 'interrupt'},
    };
  }
}

PageRouteBuilder<void> _route(Widget screen) =>
    PageRouteBuilder(pageBuilder: (context, _, _) => screen);
