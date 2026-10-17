import 'package:example/desk/customers.dart';
import 'package:example/desk/dates.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/desk/ui/highlights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _gap = 16.0;
const _lineGap = 4.0;
// How the lines table shares its width, so it shrinks with the form. A price
// like `15 550.05 PLN` must fit its column.
const _productFlex = 7;
const _quantityFlex = 4;
const _priceFlex = 5;
const _discountFlex = 3;
const _pickerSpan = Duration(days: 365);

const _labelGap = '  ';
const _empty = 'Paste a customer e-mail into the chat to start an order.';
const _noDiscount = '–';

/// The order as the user sees it: the customer, the lines with their prices,
/// the delivery and the total. The agent fills it through the cubit's
/// methods, and the user changes it through the same ones, until it is
/// placed.
final class const OrderForm({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final order = context.select<OrderDeskCubit, DeskOrder>(
      (cubit) => cubit.order,
    );
    final placed = context.select<OrderDeskCubit, PlacedOrder?>(
      (cubit) => cubit.placed,
    );
    final editable = context.select<OrderDeskCubit, bool>(
      (cubit) => cubit.canEdit,
    );
    final customer = order.customer;
    final delivery = order.delivery;
    if (customer == null && order.lines.isEmpty && delivery == null) {
      return const Center(child: Text(_empty));
    }
    return SingleChildScrollView(
      padding: const .all(_gap),
      child: Column(
        spacing: _gap,
        crossAxisAlignment: .stretch,
        children: [
          if (placed != null) _PlacedBanner(placed),
          if (customer != null || delivery != null)
            // Side by side, so the whole order fits an iPad screen.
            IntrinsicHeight(
              child: Row(
                spacing: _gap,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: const RoundedRectangleBorder(
        borderRadius: cardCorners,
        side: BorderSide(color: success),
      ),
      child: Padding(
        padding: const .all(_gap),
        child: Row(
          spacing: _gap,
          children: [
            const Icon(Icons.check_circle, color: success),
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'Placed as ${placed.id.value}',
                  style: theme.textTheme.titleMedium,
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
}

final class const _CustomerCard(final Customer customer)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Section(
    title: 'Customer',
    area: customerArea,
    children: [
      Text(customer.name, style: Theme.of(context).textTheme.titleMedium),
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
    area: deliveryArea,
    children: [
      Text(delivery.address, style: Theme.of(context).textTheme.titleMedium),
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
      firstDate: delivery.date.subtract(_pickerSpan),
      lastDate: delivery.date.add(_pickerSpan),
    );
    if (date != null && context.mounted) {
      context.read<OrderDeskCubit>().setDelivery(delivery.address, date);
    }
  }
}

/// A card with a [title] that is highlighted as [area].
final class const _Section({
  required final String title,
  required final String area,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: .antiAlias,
    child: Highlighted(
      area: area,
      child: Padding(
        padding: const .all(_gap),
        child: Column(
          spacing: _lineGap,
          crossAxisAlignment: .start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// A [label] in the muted colour, then its [value].
final class const _Detail(final String label, final String value)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label$_labelGap',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
    final label = Theme.of(context).textTheme.labelMedium;
    return Card(
      clipBehavior: .antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const .all(_gap),
            child: _columns(
              Text('Product', style: label),
              Text('Quantity', style: label, textAlign: .center),
              Text('Unit price', style: label, textAlign: .end),
              Text('Discount', style: label, textAlign: .end),
              Text('Total', style: label, textAlign: .end),
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
  Widget build(BuildContext context) {
    return Highlighted(
      area: lineArea(line.sku),
      child: Padding(
        padding: const .all(_gap),
        child: _columns(
          Column(
            crossAxisAlignment: .start,
            children: [
              Text(line.name),
              Text(line.sku, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          FittedBox(
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
          Text(line.unitPrice, textAlign: .end),
          Text(line.discount ?? _noDiscount, textAlign: .end),
          Text(line.lineTotal, textAlign: .end),
        ),
      ),
    );
  }

  void _setQuantity(BuildContext context, int quantity) =>
      context.read<OrderDeskCubit>().setQuantity(line.sku, quantity);
}

/// The five columns of the lines table.
Widget _columns(
  Widget product,
  Widget quantity,
  Widget unitPrice,
  Widget discount,
  Widget total,
) => Row(
  children: [
    Expanded(flex: _productFlex, child: product),
    Expanded(flex: _quantityFlex, child: quantity),
    Expanded(flex: _priceFlex, child: unitPrice),
    Expanded(flex: _discountFlex, child: discount),
    Expanded(flex: _priceFlex, child: total),
  ],
);

final class const _Total(final String total) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: .end,
      crossAxisAlignment: .baseline,
      textBaseline: .alphabetic,
      spacing: _gap,
      children: [
        Text('Total', style: text.titleMedium),
        // Smaller only where the form is too narrow for it.
        Flexible(
          child: FittedBox(
            fit: .scaleDown,
            child: Text(total, style: text.displaySmall),
          ),
        ),
      ],
    );
  }
}
