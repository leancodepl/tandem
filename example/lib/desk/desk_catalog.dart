import 'package:example/desk/ui/desk_widgets.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/tandem.dart';

part 'desk_catalog.g.dart';

/// An icon by name: cart, truck or receipt.
final class const DeskIconConverter()
    implements JsonConverter<IconData, String> {
  static const _icons = {
    'cart': Icons.shopping_cart,
    'truck': Icons.local_shipping,
    'receipt': Icons.receipt_long,
  };

  @override
  IconData fromJson(String json) =>
      _icons[json] ??
      (throw FormatException('Write one of ${_icons.keys.join(', ')}.'));

  @override
  String toJson(IconData object) =>
      _icons.entries.firstWhere((e) => e.value == object).key;
}

/// Start with a DeskCard. Show the customer as a CustomerCard, the order
/// lines as one OrderLine per item of /order/lines, then an OrderTotal of
/// /order, then a DeskButton for place_order when it is among your tools.
///
/// ```json
/// [
///   {"id": "root", "component": "DeskCard", "title": "Your order", "children": ["customer", "lines", "total", "place"]},
///   {"id": "customer", "component": "CustomerCard", "customer": {"path": "/order/customer"}},
///   {"id": "lines", "component": "DeskColumn", "children": {"componentId": "line", "path": "/order/lines"}},
///   {"id": "line", "component": "OrderLine", "name": {"path": "name"}, "quantity": {"path": "quantity"}, "lineTotal": {"path": "lineTotal"},
///    "onRemove": {"action": {"event": {"name": "set_quantity", "context": {"sku": {"path": "sku"}, "quantity": 0}}}},
///    "onQuantity": {"action": {"event": {"name": "set_quantity", "context": {"sku": {"path": "sku"}, "quantity": {"input": true}}}}}},
///   {"id": "total", "component": "OrderTotal", "order": {"path": "/order"}},
///   {"id": "place", "component": "DeskButton", "label": "Place order", "icon": "cart", "onPressed": {"action": {"event": {"name": "place_order"}}}}
/// ]
/// ```
@TandemCatalog(
  [DeskCard, DeskColumn, OrderLine, OrderTotal, DeskButton, CustomerCard],
  converters: [DeskIconConverter()],
)
final class const DeskCatalog() with _$DeskCatalog;
