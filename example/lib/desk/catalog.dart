class const Product({
  required final String sku,
  required final String name,
  required final String description,
  required final double price,
});

class Catalog(final List<Product> products) {
  Product bySku(String sku) => products.firstWhere(
    (product) => product.sku == sku,
    orElse: () =>
        throw ArgumentError.value(sku, 'sku', 'is not in the catalog'),
  );

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
