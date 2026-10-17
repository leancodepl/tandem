import 'package:example/order.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

part 'order_cubit.g.dart';

class OrderCubit({required final Catalog catalog, required final Orders orders})
    extends Cubit<OrderState>
    with _$OrderCubit {
  this : super(.new(draft: .empty));

  @override
  List<AgentCapability> get agent => [
    .sees(draft),
    .calls(searchCatalog),
    .calls(setQuantity),
    if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
  ];

  /// The order as the user sees it on the screen.
  OrderDraft get draft => state.draft;

  /// Finds products by name or description.
  Future<List<Product>> searchCatalog(String query) => catalog.search(query);

  /// Sets how many pieces of [sku] the order has.
  void setQuantity(String sku, int quantity) {
    if (quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must not be negative');
    }
    emit(.new(draft: draft.withQuantity(sku, quantity)));
  }

  /// Places the order exactly as it is on the screen.
  Future<OrderId> placeOrder() async {
    final submitted = draft;
    final id = await orders.place(submitted);
    // An edit made meanwhile is not in the placed order, so it must stay.
    if (identical(draft, submitted)) {
      emit(.new(draft: .empty));
    }
    return id;
  }
}
