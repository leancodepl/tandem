import 'package:example/agent_chat.dart';
import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/desk/ui/order_form.dart';
import 'package:example/desk/ui/order_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// The order form with the agent's chat beside it.
///
/// It talks to the agent at `localhost:8000`, or over [connection], such as
/// a `ScriptedAgent` in a test.
final class const OrderDeskScreen({
  super.key,
  final AgentConnection? connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OrderDeskCubit(
      catalog: Catalog(products),
      customers: Customers(customers),
      orders: Orders(),
    ),
    child: switch (connection) {
      final connection? => TandemScope.connected(
        surface: (context) => context.read<OrderDeskCubit>(),
        connection: connection,
        approvals: const .fromState(),
        child: const _OrderDeskView(),
      ),
      null => TandemScope(
        surface: (context) => context.read<OrderDeskCubit>(),
        agent: Uri.parse('http://localhost:8000/agent'),
        approvals: const .fromState(),
        child: const _OrderDeskView(),
      ),
    },
  );
}

final class const _OrderDeskView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
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
            child: AgentChat(
              approvalBuilder: (context, request) => const OrderSummary(),
            ),
          ),
        ],
      ),
    ),
  );
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
          if (customer case Customer(:final name))
            TextSpan(
              text: '  ·  $name',
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      style: context.textTheme.titleLarge,
    );
  }
}
