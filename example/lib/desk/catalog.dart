class const Product({
  required final String sku,
  required final String name,
  required final String description,

  /// The list price of one piece, in PLN.
  required final double price,
});

class Catalog(final List<Product> products) {
  /// The product with [sku]; throws an [ArgumentError] for none.
  Product bySku(String sku) => products.firstWhere(
    (product) => product.sku == sku,
    orElse: () =>
        throw ArgumentError.value(sku, 'sku', 'is not in the catalog'),
  );

  /// The products that have every word of [query] in their SKU, name or
  /// description.
  Future<List<Product>> search(String query) async {
    final words = query.toLowerCase().split(' ');
    return [
      for (final product in products)
        if (words.every(
          '${product.sku} ${product.name} ${product.description}'
              .toLowerCase()
              .contains,
        ))
          product,
    ];
  }
}
