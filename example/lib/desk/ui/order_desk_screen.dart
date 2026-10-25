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
      onEvent: wakeOnPlacedOrder,
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
        // Approve places the order as it is on the screen, which a decided
        // card would show as it is now, not as it was asked.
        approvalBuilder: (context, request) => switch (request.status) {
          .pending => const OrderSummary(),
          _ => const SizedBox.shrink(),
        },
      ),
      child: const _FormAndView(),
    ),
  );
}

/// Lets the agent answer once the user placed the order from its view.
void wakeOnPlacedOrder(
  BuildContext context,
  TandemEvent event,
  TandemSession session,
) {
  if (event case AgentCall(tool: 'place_order', caller: .view)) {
    session.wake();
  }
}

/// The form above what the agent draws, which takes at most half the height.
final class const _FormAndView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: .stretch,
      children: [
        const Expanded(child: OrderForm()),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
          child: const SingleChildScrollView(
            padding: .fromLTRB(12, 0, 12, 12),
            child: TandemView(),
          ),
        ),
      ],
    ),
  );
}
