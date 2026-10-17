int discountPercent(
  String? priceList,
  String sku,
  Map<String, int> quantities,
) {
  if (priceList != 'Acme 2026' || !sku.startsWith('VM-')) {
    return 0;
  }

  final monitors = quantities.entries
      .where((entry) => entry.key.startsWith('VM-'))
      .fold(0, (sum, entry) => sum + entry.value);

  return monitors >= 15 ? 17 : 12;
}
