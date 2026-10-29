import 'package:example/desk/customers.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:flutter/material.dart';

/// A card with a title over its children, such as the summary of the order.
final class const DeskCard({
  super.key,
  required final String title,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const .all(12),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          Text(title, style: context.textTheme.titleMedium),
          ...children,
        ],
      ),
    ),
  );
}

/// Components one below another, such as the lines of the order.
final class const DeskColumn({super.key, required final List<Widget> children})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: .stretch, spacing: 4, children: children);
}

/// One line of the order: the product, how many, and the line total.
final class const OrderLine({
  super.key,
  required final String name,
  required final int quantity,
  required final String lineTotal,
  final VoidCallback? onRemove,
  final ValueChanged<int>? onQuantity,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      Text(name),
      Wrap(
        crossAxisAlignment: .center,
        spacing: 8,
        children: [
          if (onQuantity case final change?)
            IconButton(
              tooltip: 'Fewer',
              onPressed: quantity > 0 ? () => change(quantity - 1) : null,
              icon: const Icon(Icons.remove),
            ),
          Text('$quantity pcs'),
          if (onQuantity case final change?)
            IconButton(
              tooltip: 'More',
              onPressed: () => change(quantity + 1),
              icon: const Icon(Icons.add),
            ),
          Text(lineTotal),
          TextButton(onPressed: onRemove, child: const Text('Remove')),
        ],
      ),
    ],
  );
}

/// What the whole order comes to, with how many pieces it has.
final class const OrderTotal({super.key, required final DeskOrder order})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pieces = order.lines.fold(0, (sum, line) => sum + line.quantity);

    return Column(
      crossAxisAlignment: .end,
      children: [
        Text(order.total, style: context.textTheme.titleLarge),
        Text('$pieces pcs', style: context.textTheme.bodySmall),
      ],
    );
  }
}

/// A button that does what its label says, such as placing the order.
final class const DeskButton({
  super.key,
  required final String label,
  final VoidCallback? onPressed,
  final IconData? icon,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (icon) {
    final icon? => FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
    null => FilledButton(onPressed: onPressed, child: Text(label)),
  };
}

/// The customer the order is for, with their price list.
final class const CustomerCard({super.key, required final Customer customer})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Expanded(child: Text(customer.name)),
      Text(customer.priceList, style: context.textTheme.bodySmall),
    ],
  );
}
