An order form the agent can fill. It places the order only after the user approves, and only when the order has lines.

<!-- example/lib/order_cubit.dart -->
```dart
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
```

Run `dart run build_runner build` to generate `order_cubit.g.dart`. `OrderDraft` and `Orders` are in [`order.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/order.dart).

The screen puts the chat next to the form:

<!-- example/lib/order_screen.dart -->
```dart
/// The order form with the in-app agent's chat beside it.
final class const OrderChatScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OrderCubit(orders: context.read<Orders>()),
    child: TandemScope(
      surface: (context) => context.read<OrderCubit>(),
      agent: Uri.parse('http://localhost:8000/agent'),
      approvals: const .fromState(),
      onEvent: showOrderMessages,
      child: const Row(
        children: [
          Expanded(child: OrderForm()),
          SizedBox(width: 360, child: AgentChat()),
        ],
      ),
    ),
  );
}
```

[`agent_chat.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) is the chat of the example: copy it into your app, make its texts and look your own, and import it from there. `approvals: const .fromState()` lets the chat draw the card for `place_order`, and [`showOrderMessages`](https://github.com/leancodepl/tandem/blob/main/example/lib/order_messages.dart) shows a snackbar when the order is placed or a run fails. Start an AG-UI agent on `localhost:8000` that puts `context` into the model's prompt.

One line in `main()` lets your coding agent, such as Claude Code, fill the same screens while the app runs in debug, with the skill `tandem-coding-agent`:

<!-- example/lib/main.dart -->
```dart
void main() {
  TandemBridge.enable();
  runApp(const OrderDeskApp());
}
```

No agent yet? The [example app](https://github.com/leancodepl/tandem/blob/main/example/README.md) runs a larger order desk with a scripted agent, without a backend or an API key. Its invoice list runs on Apple's on-device model:

<!-- example/lib/main_apple.dart -->
```dart
void main() => runApp(InvoiceApp(connection: OnDeviceAgent.apple()));
```

[Requirements and limits](https://github.com/leancodepl/tandem#apples-on-device-model).
