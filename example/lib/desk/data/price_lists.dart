/// The percent off [sku] for a customer on [priceList] whose order has
/// [quantities] pieces by sku.
///
/// On the Acme list monitors are 12 % off, and 17 % with 15 or more monitors
/// of any model in the order.
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
