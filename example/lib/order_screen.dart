import 'package:example/agent_chat.dart';
import 'package:example/order.dart';
import 'package:example/order_cubit.dart';
import 'package:example/order_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// The order form of the README with the agent's chat beside it. [Orders]
/// comes from a provider above it.
final class const OrderScreen({super.key}) extends StatelessWidget {
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

final class const OrderForm({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final line in context.watch<OrderCubit>().draft.lines)
        ListTile(title: Text(line.sku), trailing: Text('${line.quantity}')),
    ],
  );
}
