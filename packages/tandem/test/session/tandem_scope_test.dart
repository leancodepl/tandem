import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/shop.dart';

void main() {
  late List<Shop> shops;

  setUp(() => shops = []);

  // A new shop on every call, so a test sees which session reads which.
  Shop readShop(BuildContext context) {
    final shop = Shop();
    addTearDown(shop.close);
    shops.add(shop);
    return shop;
  }

  Widget scope(String agent) => TandemScope(
    surface: readShop,
    agent: Uri.parse(agent),
    approvals: const .fromState(),
    child: const SizedBox(),
  );

  TandemSession sessionOf(WidgetTester tester) =>
      TandemSessionScope.of(tester.element(find.byType(SizedBox)));

  testWidgets('a rebuild keeps the session', (tester) async {
    await tester.pumpWidget(scope('http://localhost/agent'));
    final session = sessionOf(tester);

    await tester.pumpWidget(scope('http://localhost/agent'));

    expect(sessionOf(tester), same(session));
    expect(shops, hasLength(1));
  });

  testWidgets('another agent opens a new session that reads the surface', (
    tester,
  ) async {
    await tester.pumpWidget(scope('http://localhost/agent'));
    final session = sessionOf(tester);

    await tester.pumpWidget(scope('http://localhost/other'));

    expect(sessionOf(tester), isNot(same(session)));
    expect([for (final shop in shops) shop.hasSession], [false, true]);
  });

  testWidgets('another connection opens a new session', (tester) async {
    Widget connected(AgentConnection connection) => TandemScope.connected(
      surface: readShop,
      connection: connection,
      approvals: const .fromState(),
      child: const SizedBox(),
    );
    await tester.pumpWidget(connected(ScriptedAgent(const [])));
    final session = sessionOf(tester);

    await tester.pumpWidget(connected(ScriptedAgent(const [])));

    expect(sessionOf(tester), isNot(same(session)));
  });

  testWidgets('onEvent gets the scope context, the session and the latest '
      'callback', (tester) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Added milk.')],
    ]);
    final heard = <(String, Widget, TandemEvent, TandemSession)>[];
    Widget listening(String name) => TandemScope.connected(
      surface: readShop,
      connection: agent,
      onEvent: (context, event, session) =>
          heard.add((name, context.widget, event, session)),
      approvals: const .fromState(),
      child: const SizedBox(),
    );
    await tester.pumpWidget(listening('first'));
    await tester.pumpWidget(listening('second'));

    sessionOf(tester).send('milk please');
    await tester.pumpAndSettle();

    final [(name, widget, event, session)] = heard;
    expect(name, 'second');
    expect(widget, isA<TandemScope>());
    expect(event, isA<AgentCall>());
    expect(session, same(sessionOf(tester)));
    expect(shops.single.items, ['milk']);
  });

  testWidgets('the approval callback gets each request in turn, with the '
      'scope context', (tester) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Shared twice.')],
    ]);
    final asked = <(String, Widget)>[];
    await tester.pumpWidget(
      TandemScope.connected(
        surface: readShop,
        connection: agent,
        approvals: .callback((context, request, session) async {
          asked.add((request.toolCallId, context.widget));
          session.approve(request);
        }),
        child: const SizedBox(),
      ),
    );

    sessionOf(tester).send('share it twice');
    await tester.pumpAndSettle();

    final [(first, scope), (second, _)] = asked;
    expect([first, second], ['call-1', 'call-2']);
    expect(scope, isA<TandemScope>());
    expect(agent.requests, hasLength(2));
  });

  testWidgets('a scope that takes no approvals refuses the call and reports '
      'it', (tester) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share')],
      (_) => const [AgentStep.say('I cannot share it here.')],
    ]);
    await tester.pumpWidget(
      TandemScope.connected(
        surface: readShop,
        connection: agent,
        approvals: const .none(),
        child: const SizedBox(),
      ),
    );

    sessionOf(tester).send('share it');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isStateError);
    expect(sessionOf(tester).items.whereType<ApprovalRequest>(), isEmpty);
    final {'messages': messages as List<Object?>} = agent.requests[1];
    expect(
      messages.last,
      containsPair('content', contains('"status":"refused"')),
    );
  });

  testWidgets('a scope without an agent takes calls of a coding agent, and '
      'fails a run with a report that names what is missing', (tester) async {
    await tester.pumpWidget(
      TandemScope(
        surface: readShop,
        approvals: const .fromState(),
        child: const SizedBox(),
      ),
    );

    final answer = await TandemBridge.call('add', arguments: {'item': 'milk'});
    sessionOf(tester).send('hi');
    await tester.pumpAndSettle();

    expect(answer, containsPair('status', 'returned'));
    expect(shops.single.items, ['milk']);
    expect(
      tester.takeException(),
      isA<AgentRunException>().having(
        (error) => error.message,
        'message',
        contains('no agent'),
      ),
    );
    expect(sessionOf(tester).items.last, const ChatNotice(.runFailed));
  });

  testWidgets('a scope disposes its session before the surface closes', (
    tester,
  ) async {
    bool? listenedOnClose;
    await tester.pumpWidget(
      _Owner(onClose: (shop) => listenedOnClose = shop.hasSession),
    );

    await tester.pumpWidget(const SizedBox());

    expect(listenedOnClose, isFalse);
  });
}

final class const _Owner({required final void Function(Shop shop) onClose})
    extends StatefulWidget {
  @override
  State<_Owner> createState() => _OwnerState();
}

final class _OwnerState() extends State<_Owner> {
  final _shop = Shop();
  final _agent = ScriptedAgent(const []);

  @override
  void dispose() {
    widget.onClose(_shop);
    unawaited(_shop.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TandemScope.connected(
    surface: (context) => _shop,
    connection: _agent,
    approvals: const .fromState(),
    child: const SizedBox(),
  );
}
