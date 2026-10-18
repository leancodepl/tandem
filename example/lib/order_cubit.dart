import 'package:example/order.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

part 'order_cubit.g.dart';

@TandemAgent()
class OrderCubit({required final Orders orders})
    extends Cubit<OrderState>
    with _$OrderCubit {
  this : super(.new(draft: .empty));

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(draft),
    .calls(setQuantity),
    if (draft.lines.isNotEmpty) .callsWithApproval(placeOrder),
  ];

  @override
  Stream<Object?> get changes => stream;

  /// The order as the user sees it on the screen.
  OrderDraft get draft => state.draft;

  /// Sets how many pieces of [sku] the order has.
  void setQuantity(String sku, int quantity) =>
      emit(.new(draft: draft.withQuantity(sku, quantity)));

  /// Places the order exactly as it is on the screen.
  Future<OrderId> placeOrder() => orders.place(draft);
}
