import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/emails.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/gallery/demo_agents.dart';
import 'package:example/recipes/approval_dialog/reply_cubit.dart';
import 'package:example/recipes/fill_from_email/contact_cubit.dart';
import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

void main() {
  testWidgets('the list agent adds its items, asks to clear them and starts '
      'over', (tester) async {
    final list = ShoppingListCubit();
    addTearDown(list.close);
    final session = await _connect(tester, list, shoppingListAgent());

    session.send('Start');
    await tester.pumpAndSettle();
    expect(list.items, ['Milk', 'Bread']);

    session.reject(_pending(session));
    await tester.pumpAndSettle();
    expect(_lastText(session), 'You rejected the action. It did not run.');

    session.send('Clear it');
    await tester.pumpAndSettle();
    session.approve(_pending(session));
    await tester.pumpAndSettle();
    expect(list.items, isEmpty);
    expect(_lastText(session), 'The shopping list is empty.');

    session.send('Start again');
    await tester.pumpAndSettle();
    expect(list.items, ['Milk', 'Bread']);
    expect(session.status, isA<AwaitingApproval>());
  });

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
    session.approve(_pending(session));
    await tester.pumpAndSettle();
    expect(orders.placed, hasLength(1));
    expect(_lastText(session), 'Order ORD-1042 placed.');

    session.send('Place it again');
    await tester.pumpAndSettle();
    expect(orders.placed, hasLength(1));
    expect(_lastText(session), 'This order is already placed.');
  });

  testWidgets('the contact agent fills the form every time it is asked', (
    tester,
  ) async {
    final contact = ContactCubit();
    addTearDown(contact.close);
    final session = await _connect(tester, contact, contactAgent());

    session.send(contactEmail);
    await tester.pumpAndSettle();
    contact.setName('Edited by hand');
    session.send(contactEmail);
    await tester.pumpAndSettle();

    expect(contact.contact.name, 'Marta Nowak');
    expect(contact.contact.email, 'marta@acme.example');
    expect(_lastText(session), 'Contact filled. You can edit the fields.');
  });

  testWidgets('the reply agent drafts the reply, then asks to send it', (
    tester,
  ) async {
    final reply = ReplyCubit();
    addTearDown(reply.close);
    final session = await _connect(tester, reply, replyAgent());

    session.send('Answer the customer');
    await tester.pumpAndSettle();
    expect(reply.reply, startsWith('Your parcel ships on Monday.'));
    session.approve(_pending(session));
    await tester.pumpAndSettle();
    expect(reply.sent, isTrue);
    expect(_lastText(session), 'The reply was sent.');

    session.send('Send it again');
    await tester.pumpAndSettle();
    expect(_lastText(session), 'The reply is already sent.');
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
