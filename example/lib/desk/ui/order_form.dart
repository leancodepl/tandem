import 'package:example/desk/customers.dart';
import 'package:example/desk/dates.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The order as the user sees it. The agent and the user change it through
/// the same cubit methods, until it is placed.
final class const OrderForm({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OrderDeskCubit>();
    final order = cubit.order;
    final placed = cubit.placed;
    final editable = cubit.canEdit;
    final customer = order.customer;
    final delivery = order.delivery;
    if (order.isEmpty) {
      return const Center(
        child: Text('Paste a customer e-mail into the chat to start an order.'),
      );
    }
    return SingleChildScrollView(
      padding: const .all(16),
      child: Column(
        spacing: 16,
        crossAxisAlignment: .stretch,
        children: [
          if (placed != null) _PlacedBanner(placed),
          if (order.hasCustomerOrDelivery)
            // Side by side, so the whole order fits an iPad screen.
            IntrinsicHeight(
              child: Row(
                spacing: 16,
                crossAxisAlignment: .stretch,
                children: [
                  if (customer != null)
                    Expanded(child: _CustomerCard(customer)),
                  if (delivery != null)
                    Expanded(
                      child: _DeliveryCard(delivery, editable: editable),
                    ),
                ],
              ),
            ),
          if (order.lines.isNotEmpty) _Lines(order.lines, editable: editable),
          if (order.lines.isNotEmpty) _Total(order.total),
        ],
      ),
    );
  }
}

final class const _PlacedBanner(final PlacedOrder placed)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    shape: const RoundedRectangleBorder(
      borderRadius: cardCorners,
      side: BorderSide(color: success),
    ),
    child: Padding(
      padding: const .all(16),
      child: Row(
        spacing: 16,
        children: [
          const Icon(Icons.check_circle, color: success),
          Column(
            crossAxisAlignment: .start,
            children: [
              Text(
                'Placed as ${placed.id.value}',
                style: context.textTheme.titleMedium,
              ),
              if (placed.order.delivery case final delivery?)
                Text('Delivery on ${formatDate(delivery.date)}'),
            ],
          ),
        ],
      ),
    ),
  );
}

final class const _CustomerCard(final Customer customer)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Section(
    title: 'Customer',
    children: [
      Text(customer.name, style: context.textTheme.titleMedium),
      _Detail('Contact', customer.contact),
      _Detail('Price list', customer.priceList),
    ],
  );
}

final class const _DeliveryCard(
  final DeskDelivery delivery, {
  required final bool editable,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Section(
    title: 'Delivery',
    children: [
      Text(delivery.address, style: context.textTheme.titleMedium),
      OutlinedButton.icon(
        onPressed: editable ? () => _pickDate(context) : null,
        icon: const Icon(Icons.calendar_today),
        label: Text(formatDate(delivery.date)),
      ),
    ],
  );

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: delivery.date,
      firstDate: delivery.date.subtract(const Duration(days: 365)),
      lastDate: delivery.date.add(const Duration(days: 365)),
    );
    if (date != null && context.mounted) {
      context.read<OrderDeskCubit>().setDelivery(delivery.address, date);
    }
  }
}

final class const _Section({
  required final String title,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const .all(16),
      child: Column(
        spacing: 4,
        crossAxisAlignment: .start,
        children: [
          Text(title, style: context.textTheme.labelMedium),
          ...children,
        ],
      ),
    ),
  );
}

final class const _Detail(final String label, final String value)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label  ',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
        TextSpan(text: value),
      ],
    ),
  );
}

final class const _Lines(
  final List<DeskLine> lines, {
  required final bool editable,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final label = context.textTheme.labelMedium;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const .all(16),
            child: _Columns(
              product: Text('Product', style: label),
              quantity: Text('Quantity', style: label, textAlign: .center),
              unitPrice: Text('Unit price', style: label, textAlign: .end),
              discount: Text('Discount', style: label, textAlign: .end),
              total: Text('Total', style: label, textAlign: .end),
            ),
          ),
          for (final line in lines)
            _LineRow(key: ValueKey(line.sku), line: line, editable: editable),
        ],
      ),
    );
  }
}

final class const _LineRow({
  super.key,
  required final DeskLine line,
  required final bool editable,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(16),
    child: _Columns(
      product: Column(
        crossAxisAlignment: .start,
        children: [
          Text(line.name),
          Text(line.sku, style: context.textTheme.bodySmall),
        ],
      ),
      quantity: FittedBox(
        fit: .scaleDown,
        child: Row(
          mainAxisSize: .min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'One less',
              onPressed: editable
                  ? () => _setQuantity(context, line.quantity - 1)
                  : null,
            ),
            Text('${line.quantity}'),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'One more',
              onPressed: editable
                  ? () => _setQuantity(context, line.quantity + 1)
                  : null,
            ),
          ],
        ),
      ),
      unitPrice: Text(line.unitPrice, textAlign: .end),
      discount: Text(line.discount ?? '–', textAlign: .end),
      total: Text(line.lineTotal, textAlign: .end),
    ),
  );

  void _setQuantity(BuildContext context, int quantity) =>
      context.read<OrderDeskCubit>().setQuantity(line.sku, quantity);
}

final class const _Columns({
  required final Widget product,
  required final Widget quantity,
  required final Widget unitPrice,
  required final Widget discount,
  required final Widget total,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    // A price like 15 550.05 PLN must fit its column.
    children: [
      Expanded(flex: 7, child: product),
      Expanded(flex: 4, child: quantity),
      Expanded(flex: 5, child: unitPrice),
      Expanded(flex: 3, child: discount),
      Expanded(flex: 5, child: total),
    ],
  );
}

final class const _Total(final String total) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: .end,
    crossAxisAlignment: .baseline,
    textBaseline: .alphabetic,
    spacing: 16,
    children: [
      Text('Total', style: context.textTheme.titleMedium),
      Flexible(
        child: FittedBox(
          fit: .scaleDown,
          child: Text(total, style: context.textTheme.displaySmall),
        ),
      ),
    ],
  );
}
