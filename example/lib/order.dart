/// The state of the order screen.
class OrderState({required final OrderDraft draft});

/// The order the user is filling in.
class const OrderDraft({required final List<OrderLine> lines}) {
  static const empty = OrderDraft(lines: []);

  /// The draft with [quantity] pieces of [sku]; none removes the line.
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

class const Product({
  required final String sku,
  required final String name,
  required final String description,
});

extension type const OrderId(String value);

/// The products the user can order.
class Catalog(final List<Product> products) {
  Future<List<Product>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    return [
      for (final product in products)
        if ('${product.name} ${product.description}'.toLowerCase().contains(
          normalizedQuery,
        ))
          product,
    ];
  }
}

/// Where placed orders go.
class Orders() {
  final placed = <OrderDraft>[];

  Future<OrderId> place(OrderDraft draft) async {
    placed.add(draft);
    return OrderId('ORD-${placed.length}');
  }
}
