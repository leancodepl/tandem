import 'package:example/desk/customers.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/desk/ui/order_form.dart';
import 'package:example/desk/ui/order_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

/// The order form with the agent's chat beside it.
///
/// It talks to the agent at `localhost:8000`, or over [connection], such as
/// a `ScriptedAgent` in a test.
final class const OrderDeskScreen({
  super.key,
  final AgentConnection? connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Padding(padding: .fromLTRB(16, 16, 16, 0), child: _Header()),
                  Expanded(child: OrderForm()),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 360,
              child: TandemChat(
                approvalBuilder: (context, request) => const OrderSummary(),
              ),
            ),
          ],
        ),
      ),
    );
    return BlocProvider(
      create: (context) => OrderDeskCubit(
        catalog: .demo(),
        customers: .demo(),
        orders: Orders(),
      ),
      child: switch (connection) {
        final connection? => TandemScope<OrderDeskCubit>.connected(
          connection: connection,
          child: screen,
        ),
        null => TandemScope<OrderDeskCubit>(
          agent: Uri.parse('http://localhost:8000/agent'),
          child: screen,
        ),
      },
    );
  }
}

final class const _Header() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final customer = context.select<OrderDeskCubit, Customer?>(
      (cubit) => cubit.order.customer,
    );
    return Text.rich(
      TextSpan(
        text: 'Order desk',
        children: [
          if (customer != null)
            TextSpan(
              text: '  ·  ${customer.name}',
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      style: context.textTheme.titleLarge,
    );
  }
}
