import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

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
    void Function(BuildContext, TandemEvent, TandemSession)? onEvent,
  }) => TandemScope(
    surface: (context) => shop,
    approvals: const .fromState(),
    onEvent: onEvent,
    child: const SizedBox(),
  );

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
      'onEvent hears it', (tester) async {
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
      isA<AgentCall>().having((call) => call.tool, 'tool', 'add').having(
        (call) => call.arguments,
        'arguments',
        {'item': 'milk'},
      ),
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

  test('enable twice does not throw', () {
    TandemBridge.enable();

    expect(TandemBridge.enable, returnsNormally);
  });
}

PageRouteBuilder<void> _route(Widget screen) =>
    PageRouteBuilder(pageBuilder: (context, _, _) => screen);
