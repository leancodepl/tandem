import 'package:example/agent_chat.dart';
import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/customers.dart';
import 'package:example/desk/data/emails.dart';
import 'package:example/desk/data/products.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/desk/ui/agent_workspace.dart';
import 'package:example/desk/ui/order_form.dart';
import 'package:example/desk/ui/order_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// The order form with the agent's chat.
final class const OrderDeskScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OrderDeskCubit(
      catalog: Catalog(products),
      customers: Customers(customers),
      orders: Orders(),
    ),
    child: TandemScope.connected(
      surface: (context) => context.read<OrderDeskCubit>(),
      connection: connection,
      approvals: const .fromState(),
      child: const _OrderDeskView(),
    ),
  );
}

final class const _OrderDeskView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AgentWorkspace(
      title: 'Order draft',
      chat: AgentChat(
        suggestion: orderEmail,
        approvalBuilder: (context, request) => const OrderSummary(),
      ),
      child: const OrderForm(),
    ),
  );
}
