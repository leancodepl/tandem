import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/money.dart';
import 'package:example/desk/price_list.dart';

/// The order as the user sees it, with every price worked out.
class const DeskOrder({
  final Customer? customer,
  required final List<DeskLine> lines,
  final DeskDelivery? delivery,
  required final String total,
});

class const DeskLine({
  required final String sku,
  required final String name,
  required final int quantity,

  /// The price of one piece after the discount.
  required final String unitPrice,

  /// The discount on the list price, like `12 %`, or null for none.
  final String? discount,
  required final String lineTotal,
});

class const DeskDelivery({
  required final String address,
  required final DateTime date,
});

/// The number a placed order gets, like `ORD-1042`.
extension type const OrderId(String value);

/// An order that was placed, as it was on the screen at that moment.
class const PlacedOrder({
  required final OrderId id,
  required final DeskOrder order,
});

/// What the user has put on the screen: prices are worked out from it.
class const OrderDeskState({
  final Customer? customer,

  /// The pieces by sku, in the order the products were added.
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

  /// The order with the prices from [catalog] and the customer's price list.
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
