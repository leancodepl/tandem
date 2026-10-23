import 'package:example/agent_chat.dart';
import 'package:example/order.dart';
import 'package:example/order_cubit.dart';
import 'package:example/order_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// The order form of the README, which a coding agent fills in a debug
/// build. [Orders] comes from a provider above it.
final class const OrderScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OrderCubit(orders: context.read<Orders>()),
    child: TandemScope(
      surface: (context) => context.read<OrderCubit>(),
      approvals: const .callback(confirmOrder),
      child: const Scaffold(body: OrderForm()),
    ),
  );
}

/// The order form with the in-app agent's chat beside it.
final class const OrderChatScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OrderCubit(orders: context.read<Orders>()),
    child: TandemScope(
      surface: (context) => context.read<OrderCubit>(),
      agent: Uri.parse('http://localhost:8000/agent'),
      approvals: const .fromState(),
      onEvent: showOrderMessages,
      child: const Row(
        children: [
          Expanded(child: OrderForm()),
          SizedBox(width: 360, child: AgentChat()),
        ],
      ),
    ),
  );
}

Future<void> confirmOrder(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final draft = context.read<OrderCubit>().draft;
  final place = await showDialog<bool>(
    context: context,
    builder: (context) => _PlaceOrderDialog(draft),
  );
  try {
    if (place ?? false) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // The order changed, or the screen closed, while the dialog showed.
  }
}

final class const _PlaceOrderDialog(final OrderDraft draft)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Place this order?'),
    content: Text(
      [for (final line in draft.lines) '${line.quantity} × ${line.sku}']
          .join('\n'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Place order'),
      ),
    ],
  );
}

final class const OrderForm({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final line in context.watch<OrderCubit>().draft.lines)
        ListTile(title: Text(line.sku), trailing: Text('${line.quantity}')),
    ],
  );
}
