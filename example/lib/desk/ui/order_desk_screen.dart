import 'dart:async';

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
      child: const _AsksAgainAfterEdit(_OrderDeskView()),
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
      child: const OrderForm(),
    ),
  );
}

/// Whether the in-app agent's latest request was invalidated and nobody wrote
/// since, so the agent has not heard of it yet.
bool agentMustAskAgain(TandemSession session) => switch ([
  for (final item in session.items)
    if (item is ApprovalRequest || item is UserMessage) item,
].lastOrNull) {
  ApprovalRequest(status: .invalidated, caller: .inAppAgent) => true,
  _ => false,
};

/// Wakes the agent when [agentMustAskAgain] and the order has been still for
/// a second, so that a few taps on + end in one new request.
final class const _AsksAgainAfterEdit(final Widget child)
    extends StatefulWidget {
  @override
  State<_AsksAgainAfterEdit> createState() => _AsksAgainAfterEditState();
}

final class _AsksAgainAfterEditState() extends State<_AsksAgainAfterEdit> {
  late final StreamSubscription<Object?> _orderChanges;
  late TandemSession _session;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    _orderChanges = context.read<OrderDeskCubit>().stream.listen(
      (_) => _waitForStillOrder(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = TandemSessionScope.of(context);
    _waitForStillOrder();
  }

  @override
  void dispose() {
    _settle?.cancel();
    unawaited(_orderChanges.cancel());
    super.dispose();
  }

  void _waitForStillOrder() {
    _settle?.cancel();
    if (agentMustAskAgain(_session)) {
      _settle = Timer(const Duration(seconds: 1), _askAgain);
    }
  }

  void _askAgain() {
    if (agentMustAskAgain(_session)) {
      _session.wake();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
