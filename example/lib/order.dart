class OrderState({required final OrderDraft draft});

class const OrderDraft({required final List<OrderLine> lines}) {
  static const empty = OrderDraft(lines: []);

  OrderDraft withQuantity(String sku, int quantity) => .new(
    lines: [
      for (final line in lines)
        if (line.sku != sku)
          line
        else if (quantity > 0)
          OrderLine(sku: sku, quantity: quantity),
      if (quantity > 0 && !lines.any((line) => line.sku == sku))
        OrderLine(sku: sku, quantity: quantity),
    ],
  );
}

/// One product of an order and how many pieces of it.
class const OrderLine({
  /// The product's code in the catalog.
  required final String sku,

  /// How many pieces.
  required final int quantity,
});

extension type const OrderId(String value);

class Orders() {
  final placed = <OrderDraft>[];

  Future<OrderId> place(OrderDraft draft) async {
    placed.add(draft);
    return OrderId('ORD-${placed.length}');
  }
}
