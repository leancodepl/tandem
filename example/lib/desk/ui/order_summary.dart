import 'package:example/desk/dates.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The approval card of `place_order`: the order as it is on the screen,
/// which is what the method places.
final class const OrderSummary({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderDeskCubit>().order;
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(switch (order.customer) {
          null => 'Place order',
          final customer => 'Place order for ${customer.name}',
        }, style: context.textTheme.titleSmall),
        for (final line in order.lines)
          Row(
            spacing: 8,
            children: [
              Expanded(child: Text('${line.quantity} × ${line.name}')),
              Text(line.lineTotal),
            ],
          ),
        if (order.delivery case final delivery?)
          Text('Delivery: ${delivery.address}, ${formatDate(delivery.date)}'),
        if (order.lines.isNotEmpty)
          Row(
            spacing: 8,
            children: [
              const Expanded(child: Text('Total')),
              Text(order.total),
            ],
          ),
      ],
    );
  }
}
