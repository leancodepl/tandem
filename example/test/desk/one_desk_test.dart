import 'dart:async';

import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/desk_catalog.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/desk/ui/desk_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

part 'one_desk_test.g.dart';

/// Reports every route change, so that the agent list can follow it.
final class RouteTracker() extends NavigatorObserver {
  final key = GlobalKey<NavigatorState>();
  final _changes = StreamController<Object?>.broadcast();

  String? current;

  Stream<Object?> get changes => _changes.stream;

  void push(String route) => key.currentState?.pushNamed(route);

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) =>
      _show(route);

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      _show(previousRoute);

  void _show(Route<Object?>? route) {
    current = route?.settings.name;
    _changes.add(current);
  }
}

/// The surface of the whole app: its list follows the route.
@TandemAgent()
final class ShopAgent({
  required final OrderDeskCubit desk,
  required final RouteTracker routes,
}) with _$ShopAgent {
  @override
  List<AgentCapability> get agentCapabilities => switch (routes.current) {
    '/desk' => [
      .sees(order),
      .calls(setQuantity),
      if (desk.canPlace) .callsWithApproval(placeOrder),
      .calls(openCatalog),
    ],
    '/catalog' => [.sees(catalog), .calls(openDesk)],
    _ => [.calls(openDesk)],
  };

  @override
  Stream<Object?> get changes => Stream.multi((controller) {
    final subscriptions = [
      desk.stream.listen(controller.add),
      routes.changes.listen(controller.add),
    ];
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  }, isBroadcast: true);

  /// The order as the user sees it on the desk.
  DeskOrder get order => desk.order;

  /// The products of the shop.
  List<Product> get catalog => products;

  /// Sets how many pieces of [sku] the order has; 0 removes the line.
  void setQuantity(String sku, int quantity) => desk.setQuantity(sku, quantity);

  /// Places the order exactly as it is on the desk.
  Future<OrderId> placeOrder() => desk.placeOrder();

  /// Opens the catalog of products.
  void openCatalog() => routes.push('/catalog');

  /// Opens the order desk.
  void openDesk() => routes.push('/desk');
}

void main() {
  testWidgets('the route changes the list: the desk view empties on the '
      'catalog, the request is invalidated, and the view comes back on the '
      'desk', (tester) async {
    final desk =
        OrderDeskCubit(
            catalog: Catalog(products),
            customers: Customers(customers),
            orders: Orders(),
          )
          ..setCustomer('acme')
          ..setQuantity('VC-HDMI-2M', 40)
          ..setQuantity('VM-27Q', 12)
          ..setDelivery('Magazynowa 5, 61-001 Poznań', .utc(2026, 11, 2));
    addTearDown(desk.close);
    final routes = RouteTracker();
    final shop = ShopAgent(desk: desk, routes: routes);
    late TandemSession session;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: routes.key,
        navigatorObservers: [routes],
        initialRoute: '/desk',
        routes: {
          '/': (context) => const Text('Home'),
          '/desk': (context) => const Text('Desk'),
          '/catalog': (context) => const Text('Catalog'),
          '/settings': (context) => const Text('Settings'),
        },
        builder: (context, child) => TandemScope.connected(
          surface: (context) => shop,
          connection: ScriptedAgent([
            (_) => [
              AgentStep.callTool('tandem_show_view', {
                'components': const DeskCatalog().example,
              }),
              const AgentStep.callTool('place_order'),
            ],
          ]),
          approvals: const .fromState(),
          // Above the navigator, the desk brings its own overlay, for the
          // tooltips of its widgets.
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  session = TandemSessionScope.of(context);
                  return Material(
                    child: Column(
                      children: [
                        Expanded(child: child ?? const SizedBox()),
                        const SingleChildScrollView(
                          child: TandemView(catalog: DeskCatalog()),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    final onDesk = session;
    session.send('Show the order and place it');
    await tester.pumpAndSettle();
    final request = session.items.whereType<ApprovalRequest>().single;
    expect(find.byType(OrderLine), findsNWidgets(2));
    expect(find.byType(CustomerCard), findsOneWidget);

    routes.push('/catalog');
    await tester.pumpAndSettle();
    expect(find.byType(OrderLine), findsNothing);
    expect(find.byType(CustomerCard), findsNothing);
    expect(find.text('Your order'), findsOneWidget);
    expect(
      session.items.whereType<ApprovalRequest>().single.status,
      ApprovalStatus.invalidated,
    );
    expect(() => session.approve(request), throwsA(isA<ApprovalNotPending>()));

    routes.push('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(OrderLine), findsNothing);
    expect(AgentListing.of(shop).toolNames, ['open_desk']);

    routes.key.currentState
      ?..pop()
      ..pop();
    await tester.pumpAndSettle();
    expect(routes.current, '/desk');
    expect(find.byType(OrderLine), findsNWidgets(2));
    expect(session, same(onDesk));
    expect(desk.orders.placed, isEmpty);
  });
}
