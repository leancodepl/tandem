import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/emails.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/order_desk_agent.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

void main() {
  testWidgets('the order desk agent fills the order and places it once', (
    tester,
  ) async {
    final orders = Orders();
    final order = OrderDeskCubit(
      catalog: Catalog(products),
      customers: Customers(customers),
      orders: orders,
    );
    addTearDown(order.close);
    final session = await _connect(tester, order, orderDeskAgent());

    session.send(orderEmail);
    await tester.pumpAndSettle();
    expect(order.state.quantities, {'VC-HDMI-2M': 40, 'VM-27Q': 12});
    expect(session.status, isA<Idle>());

    session.send('Place the order');
    await tester.pumpAndSettle();
    session.reject(_pending(session));
    await tester.pumpAndSettle();
    expect(_lastText(session), 'You rejected the action. It did not run.');

    session.send('Place the order');
    await tester.pumpAndSettle();
    session.approve(_pending(session));
    await tester.pumpAndSettle();
    expect(orders.placed, hasLength(1));
    expect(_lastText(session), 'Order ORD-1042 placed.');

    session.send('Place it again');
    await tester.pumpAndSettle();
    expect(orders.placed, hasLength(1));
    expect(_lastText(session), 'This order is already placed.');
  });
}

Future<TandemSession> _connect(
  WidgetTester tester,
  AgentSurface surface,
  AgentConnection connection,
) async {
  late TandemSession session;
  await tester.pumpWidget(
    TandemScope.connected(
      surface: (context) => surface,
      connection: connection,
      approvals: const .fromState(),
      child: Builder(
        builder: (context) {
          session = TandemSessionScope.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return session;
}

ApprovalRequest _pending(TandemSession session) => switch (session.status) {
  AwaitingApproval(:final request) => request,
  final status => throw StateError('Expected an approval, got $status.'),
};

String _lastText(TandemSession session) =>
    session.items.whereType<AgentMessage>().last.text;
