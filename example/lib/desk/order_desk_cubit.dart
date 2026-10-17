import 'package:example/desk/catalog.dart';
import 'package:example/desk/customers.dart';
import 'package:example/desk/desk_order.dart';
import 'package:example/desk/orders.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

part 'order_desk_cubit.g.dart';

@TandemAgent()
class OrderDeskCubit({
  required final Catalog catalog,
  required final Customers customers,
  required final Orders orders,
}) extends Cubit<OrderDeskState> with _$OrderDeskCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(order),
    .calls(searchCatalog),
    if (canEdit) ...[
      .calls(setCustomer),
      .calls(setQuantity),
      .calls(setDelivery),
    ],
    if (canPlace) .callsWithApproval(placeOrder),
  ];

  /// The order as the user sees it on the screen.
  DeskOrder get order => state.priced(catalog);

  /// What was placed, or null while the order is not placed yet.
  PlacedOrder? get placed => state.placed;

  /// Whether the order can still change: a placed order is read-only.
  bool get canEdit => placed == null;

  /// Whether the order has lines, a customer and a delivery, and is not
  /// placed yet.
  bool get canPlace =>
      canEdit &&
      state.quantities.isNotEmpty &&
      state.customer != null &&
      state.delivery != null;

  /// Finds products by SKU, name or description.
  Future<List<Product>> searchCatalog(String query) => catalog.search(query);

  /// Sets the customer the order is for; prices follow their price list.
  void setCustomer(String customerId) =>
      emit(state.copyWith(customer: customers.byId(customerId)));

  /// Sets how many pieces of [sku] the order has; 0 removes the line.
  void setQuantity(String sku, int quantity) {
    catalog.bySku(sku); // throws for an unknown sku
    if (quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must not be negative');
    }
    final quantities = {...state.quantities, sku: quantity}
      ..removeWhere((_, pieces) => pieces == 0);
    emit(state.copyWith(quantities: quantities));
  }

  /// Sets where and when the order is delivered.
  void setDelivery(String address, DateTime date) => emit(
    state.copyWith(
      delivery: .new(address: address, date: date),
    ),
  );

  /// Places the order exactly as it is on the screen.
  Future<OrderId> placeOrder() async {
    // Placing takes a while, and the user may change the screen meanwhile:
    // that is not part of what is placed.
    final snapshot = order;
    final id = await orders.place(snapshot);
    // The screen may have closed while the order was placed.
    if (!isClosed) {
      emit(
        state.copyWith(
          placed: .new(id: id, order: snapshot),
        ),
      );
    }
    return id;
  }
}
