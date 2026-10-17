const _acmeList = 'Acme 2026';
const _monitorPrefix = 'VM-';
const _monitorDiscount = 12;
const _bulkMonitors = 15;
const _bulkExtraDiscount = 5;

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
  if (priceList != _acmeList || !sku.startsWith(_monitorPrefix)) {
    return 0;
  }
  final monitors = quantities.entries
      .where((entry) => entry.key.startsWith(_monitorPrefix))
      .fold(0, (sum, entry) => sum + entry.value);
  return monitors >= _bulkMonitors
      ? _monitorDiscount + _bulkExtraDiscount
      : _monitorDiscount;
}
