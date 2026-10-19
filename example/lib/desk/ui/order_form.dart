import 'package:example/desk/customers.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class const OrderForm({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<OrderDeskCubit>();
    final order = cubit.order;
    final editable = cubit.canEdit;

    if (order.isEmpty) {
      return const Center(
        child: Text('Paste a customer e-mail into the chat to start an order.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;

        return SingleChildScrollView(
          padding: .all(compact ? 8 : 16),
          child: Column(
            spacing: compact ? 8 : 16,
            crossAxisAlignment: .stretch,
            children: [
              if (cubit.placed case final placed?) _PlacedBanner(placed),
              if (order.hasCustomerOrDelivery && !compact)
                _CustomerAndDelivery(order, editable: editable, compact: false),
              if (order.lines.isNotEmpty) ...[
                _Lines(order.lines, editable: editable, compact: compact),
                _Total(order.total, compact: compact),
              ],
              if (order.hasCustomerOrDelivery && compact)
                Material(
                  type: .transparency,
                  child: ExpansionTile(
                    tilePadding: const .symmetric(horizontal: 8),
                    title: const Text('Customer and delivery'),
                    children: [
                      _CustomerAndDelivery(
                        order,
                        editable: editable,
                        compact: true,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

final class const _CustomerAndDelivery(
  final DeskOrder order, {
  required final bool editable,
  required final bool compact,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cards = [
      if (order.customer case final customer?) _CustomerCard(customer),
      if (order.delivery case final delivery?)
        _DeliveryCard(delivery, editable: editable),
    ];

    return compact
        ? Column(spacing: 8, crossAxisAlignment: .stretch, children: cards)
        : IntrinsicHeight(
            child: Row(
              spacing: 16,
              crossAxisAlignment: .stretch,
              children: [for (final card in cards) Expanded(child: card)],
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
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'Placed as ${placed.id.value}',
                  style: context.textTheme.titleMedium,
                ),
                if (placed.order.delivery case final delivery?)
                  Text(
                    'Delivery on ${MaterialLocalizations.of(context).formatShortDate(delivery.date)}',
                  ),
              ],
            ),
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
        label: Text(
          MaterialLocalizations.of(context).formatShortDate(delivery.date),
        ),
      ),
    ],
  );

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: delivery.date,
      firstDate: delivery.date.subtract(const Duration(days: 365)),
      lastDate: delivery.date.add(const Duration(days: 365)),
    );
    if (picked case final date? when context.mounted) {
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
  required final bool compact,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final label = context.textTheme.labelMedium;

    return Card(
      child: Column(
        children: [
          if (!compact)
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
            Padding(
              key: ValueKey(line.sku),
              padding: .all(compact ? 8 : 16),
              child: compact
                  ? _CompactLine(line, editable: editable)
                  : _LineRow(line, editable: editable),
            ),
        ],
      ),
    );
  }
}

final class const _LineRow(final DeskLine line, {required final bool editable})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Columns(
    product: Column(
      crossAxisAlignment: .start,
      children: [
        Text(line.name),
        Text(line.sku, style: context.textTheme.bodySmall),
      ],
    ),
    quantity: FittedBox(
      fit: .scaleDown,
      child: _Quantity(line, editable: editable),
    ),
    unitPrice: Text(line.unitPrice, textAlign: .end),
    discount: Text(line.discount ?? '–', textAlign: .end),
    total: Text(line.lineTotal, textAlign: .end),
  );
}

final class const _CompactLine(
  final DeskLine line, {
  required final bool editable,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final small = context.textTheme.bodySmall;

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    line.name,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.textTheme.titleSmall,
                  ),
                  Text(line.sku, style: small),
                ],
              ),
            ),
            _Quantity(line, editable: editable),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Wrap(
                spacing: 4,
                children: [
                  Text(line.unitPrice, style: small),
                  Text('each', style: small),
                  if (line.discount case final discount?)
                    Text('$discount off', style: small),
                ],
              ),
            ),
            Text(line.lineTotal, style: context.textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

final class const _Quantity(final DeskLine line, {required final bool editable})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
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
    children: [
      Expanded(flex: 7, child: product),
      Expanded(flex: 4, child: quantity),
      Expanded(flex: 5, child: unitPrice),
      Expanded(flex: 3, child: discount),
      Expanded(flex: 5, child: total),
    ],
  );
}

final class const _Total(final String total, {required final bool compact})
    extends StatelessWidget {
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
          child: Text(
            total,
            style: compact
                ? context.textTheme.titleLarge
                : context.textTheme.displaySmall,
          ),
        ),
      ),
    ],
  );
}
