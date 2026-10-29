import 'package:example/agent_chat.dart';
import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/desk_catalog.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/desk/ui/desk_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  late OrderDeskCubit cubit;

  setUp(() {
    cubit =
        OrderDeskCubit(
            catalog: Catalog(products),
            customers: Customers(customers),
            orders: Orders(),
          )
          ..setCustomer('acme')
          ..setQuantity('VC-HDMI-2M', 40)
          ..setQuantity('VM-27Q', 12)
          ..setDelivery('Magazynowa 5, 61-001 Poznań', .utc(2026, 11, 2));
  });

  tearDown(() => cubit.close());

  List<String?> total(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: find.byType(OrderTotal), matching: find.byType(Text)),
    ))
      text.data,
  ];

  testWidgets('the agent draws the order and the user removes a line', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => [
        AgentStep.callTool('tandem_show_view', {
          'components': const DeskCatalog().example,
        }),
        const AgentStep.say('Here is your order.'),
      ],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: TandemScope.connected(
            surface: (context) => context.read<OrderDeskCubit>(),
            connection: agent,
            approvals: const .fromState(),
            child: const Column(
              children: [
                TandemView(catalog: DeskCatalog()),
                Expanded(child: AgentChat()),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Show me the order');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderLine), findsNWidgets(2));
    expect(total(tester), [cubit.order.total, '52 pcs']);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(cubit.order.lines, hasLength(1));
    expect(total(tester), [
      cubit.order.total,
      '${cubit.order.lines.single.quantity} pcs',
    ]);
  });
}
