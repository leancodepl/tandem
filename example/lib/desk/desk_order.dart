import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/data/price_lists.dart';
import 'package:example/desk/money.dart';

class const DeskOrder({
  final Customer? customer,
  required final List<DeskLine> lines,
  final DeskDelivery? delivery,
  required final String total,
}) {
  bool get isEmpty => customer == null && lines.isEmpty && delivery == null;

  bool get hasCustomerOrDelivery => customer != null || delivery != null;
}

class const DeskLine({
  required final String sku,
  required final String name,
  required final int quantity,
  required final String unitPrice,
  final String? discount,
  required final String lineTotal,
});

class const DeskDelivery({
  required final String address,
  required final DateTime date,
});

extension type const OrderId(String value);

class const PlacedOrder({
  required final OrderId id,
  required final DeskOrder order,
});

class const OrderDeskState({
  final Customer? customer,
  final Map<String, int> quantities = const {},
  final DeskDelivery? delivery,
  final PlacedOrder? placed,
}) {
  OrderDeskState copyWith({
    Customer? customer,
    Map<String, int>? quantities,
    DeskDelivery? delivery,
    PlacedOrder? placed,
  }) => .new(
    customer: customer ?? this.customer,
    quantities: quantities ?? this.quantities,
    delivery: delivery ?? this.delivery,
    placed: placed ?? this.placed,
  );

  DeskOrder priced(Catalog catalog) {
    final lines = <DeskLine>[];
    var total = 0;
    for (final MapEntry(key: sku, value: quantity) in quantities.entries) {
      final product = catalog.bySku(sku);
      final percent = discountPercent(customer?.priceList, sku, quantities);
      final unitPrice = withDiscount(toGrosze(product.price), percent);
      total += unitPrice * quantity;
      lines.add(
        DeskLine(
          sku: sku,
          name: product.name,
          quantity: quantity,
          unitPrice: formatPln(unitPrice),
          discount: percent == 0 ? null : '$percent %',
          lineTotal: formatPln(unitPrice * quantity),
        ),
      );
    }

    return DeskOrder(
      customer: customer,
      lines: lines,
      delivery: delivery,
      total: formatPln(total),
    );
  }
}
