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
      child: const SizedBox(),
    );
    await tester.pumpWidget(connected(ScriptedAgent(const [])));
    final session = sessionOf(tester);

    await tester.pumpWidget(connected(ScriptedAgent(const [])));

    expect(sessionOf(tester), isNot(same(session)));
  });

  testWidgets('onAgentCall gets the scope context and the latest callback', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Added milk.')],
    ]);
    final heard = <(String, Widget)>[];
    Widget listening(String name) => TandemScope.connected(
      surface: readShop,
      connection: agent,
      onAgentCall: (context, _) => heard.add((name, context.widget)),
      child: const SizedBox(),
    );
    await tester.pumpWidget(listening('first'));
    await tester.pumpWidget(listening('second'));

    sessionOf(tester).send('milk please');
    await tester.pumpAndSettle();

    final [(name, widget)] = heard;
    expect(name, 'second');
    expect(widget, isA<TandemScope>());
    expect(shops.single.items, ['milk']);
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
    child: const SizedBox(),
  );
}
