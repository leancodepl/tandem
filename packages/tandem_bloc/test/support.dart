// A tiny order screen built the way an app builds it with tandem_bloc: an
// existing cubit with AgentEditable, a TandemScope on the route, and a screen
// that reads the TandemCubit.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

/// The order draft the agent and the user fill in together.
final class OrderDraft {
  const OrderDraft({this.customer = '', this.quantity = 0});

  factory OrderDraft.fromJson(Map<String, Object?> json) => OrderDraft(
    customer: json['customer'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );

  final String customer;
  final int quantity;

  OrderDraft copyWith({String? customer, int? quantity}) => OrderDraft(
    customer: customer ?? this.customer,
    quantity: quantity ?? this.quantity,
  );

  Map<String, Object?> toJson() => {'customer': customer, 'quantity': quantity};

  @override
  bool operator ==(Object other) =>
      other is OrderDraft &&
      other.customer == customer &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(customer, quantity);

  @override
  String toString() => 'OrderDraft($customer, $quantity)';
}

/// The state of the order screen: the shared draft, plus a flag of the
/// screen that the agent never sees.
final class OrderState {
  const OrderState({this.draft = const OrderDraft(), this.isExpanded = false});

  final OrderDraft draft;
  final bool isExpanded;

  OrderState copyWith({OrderDraft? draft, bool? isExpanded}) => OrderState(
    draft: draft ?? this.draft,
    isExpanded: isExpanded ?? this.isExpanded,
  );

  @override
  bool operator ==(Object other) =>
      other is OrderState &&
      other.draft == draft &&
      other.isExpanded == isExpanded;

  @override
  int get hashCode => Object.hash(draft, isExpanded);

  @override
  String toString() => 'OrderState($draft, isExpanded: $isExpanded)';
}

/// The screen's existing cubit. The mixin is the only change for Tandem.
class OrderCubit extends Cubit<OrderState> with AgentEditable<OrderState> {
  OrderCubit([super.initialState = const OrderState()]);

  void setCustomer(String customer) =>
      emit(state.copyWith(draft: state.draft.copyWith(customer: customer)));

  void setQuantity(int quantity) =>
      emit(state.copyWith(draft: state.draft.copyWith(quantity: quantity)));

  void toggleExpanded() => emit(state.copyWith(isExpanded: !state.isExpanded));
}

/// Shares only the draft, under `order`.
final orderCodec = StateCodec.lens<OrderState, OrderDraft>(
  'order',
  get: (state) => state.draft,
  set: (state, draft) => state.copyWith(draft: draft),
  fromJson: OrderDraft.fromJson,
  toJson: (draft) => draft.toJson(),
);

/// The app's order service, which keeps what it placed.
final class Orders {
  final placed = <OrderDraft>[];

  Future<Map<String, Object?>> place(OrderDraft draft) async {
    placed.add(draft);
    return {'number': 'ZAM/2026/0042'};
  }
}

/// The screen's tools, as a route declares them.
List<Tool<OrderState>> orderTools(BuildContext context) => [
  Tool(
    'place_order',
    'Place the order exactly as it is on the screen.',
    needsApproval: true,
    label: 'Place the order',
    run: (call) => context.read<Orders>().place(call.state.draft),
  ),
];

/// The route: the cubit's BlocProvider with a TandemScope under it.
///
/// [cubit] is closed by its BlocProvider when the route leaves the tree.
Widget orderRoute({
  required OrderCubit cubit,
  AgentConnection? connection,
  List<Tool<OrderState>> Function(BuildContext context)? tools = orderTools,
  TandemOptions options = const TandemOptions(),
}) => BlocProvider(
  create: (context) => cubit,
  child: TandemScope<OrderCubit, OrderState>(
    codec: orderCodec,
    tools: tools,
    connection: connection,
    options: options,
    child: const OrderScreen(),
  ),
);

/// The app around a route: the [connection] provided as an
/// [AgentConnection], and [orders].
Widget orderApp({
  required Widget route,
  AgentConnection? connection,
  Orders? orders,
}) => MaterialApp(
  home: Scaffold(
    body: MultiRepositoryProvider(
      providers: [
        if (connection != null)
          RepositoryProvider<AgentConnection>.value(value: connection),
        RepositoryProvider.value(value: orders ?? Orders()),
      ],
      child: route,
    ),
  ),
);

/// The order form, the timeline and a composer.
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final draft = context.select<OrderCubit, OrderDraft>(
      (cubit) => cubit.state.draft,
    );
    final view = context.watch<TandemCubit>().state;
    return SingleChildScrollView(
      child: Column(
        children: [
          OrderField(
            key: const Key('customer'),
            label: 'Customer',
            value: draft.customer,
            isFromAgent: view.marks.has('customer'),
            onChanged: (value) => context.read<OrderCubit>().setCustomer(value),
          ),
          OrderField(
            key: const Key('quantity'),
            label: 'Quantity',
            value: '${draft.quantity}',
            isFromAgent: view.marks.has('quantity'),
            onChanged: (value) => context.read<OrderCubit>().setQuantity(
              int.tryParse(value) ?? 0,
            ),
          ),
          for (final item in view.timeline)
            TimelineEntry(key: ValueKey(item.id), item: item),
          if (view.isRunning) const Text('Working'),
          const Composer(),
        ],
      ),
    );
  }
}

/// A text field that shows its value whoever changed it, the user or the
/// agent, and marks a value the agent wrote.
class OrderField extends StatefulWidget {
  const OrderField({
    super.key,
    required this.label,
    required this.value,
    required this.isFromAgent,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool isFromAgent;
  final ValueChanged<String> onChanged;

  @override
  State<OrderField> createState() => _OrderFieldState();
}

class _OrderFieldState extends State<OrderField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(OrderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: widget.isFromAgent
          ? const Tooltip(
              message: 'Filled by the assistant',
              child: Icon(Icons.auto_awesome),
            )
          : null,
    ),
  );
}

/// One item of the timeline.
class TimelineEntry extends StatelessWidget {
  const TimelineEntry({super.key, required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) => switch (item) {
    UserMessage(:final text) => Text('You: $text'),
    AgentMessage(:final text) => Text(text),
    ToolActivity(:final label) => Text(label),
    final ApprovalRequest request => ApprovalCard(request: request),
  };
}

/// The user's decision on one approval request.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({super.key, required this.request});

  final ApprovalRequest request;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        Text(request.label),
        if (request.isStale)
          const Text('The details changed, ask the assistant again'),
        if (request.status == ApprovalStatus.executed) const Text('Placed'),
        FilledButton(
          onPressed: request.canApprove ? request.approve : null,
          child: const Text('Approve'),
        ),
        TextButton(
          onPressed: request.canReject ? request.reject : null,
          child: const Text('Reject'),
        ),
      ],
    ),
  );
}

/// The message field and its send button.
class Composer extends StatefulWidget {
  const Composer({super.key});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    unawaited(context.read<TandemCubit>().send(text));
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(key: const Key('composer'), controller: _controller),
      ),
      IconButton(
        key: const Key('send'),
        onPressed: _send,
        icon: const Icon(Icons.send),
      ),
    ],
  );
}

/// Types [text] into the composer, sends it and lets the agent work.
Future<void> sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('composer')), text);
  await tester.tap(find.byKey(const Key('send')));
  await tester.pumpAndSettle();
}

/// The text field of the [OrderField] with [key].
Finder fieldOf(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

/// The text the [OrderField] with [key] shows.
String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(fieldOf(key)).controller!.text;

/// The agent's mark on the [OrderField] with [key].
Finder markOf(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byTooltip('Filled by the assistant'),
);

/// The Approve button of the only approval card.
FilledButton approveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'));

/// An [AgentConnection] whose events the test sends by hand, delivered
/// synchronously: an event sent while the session listens has reached it
/// when [send] returns.
final class LiveConnection implements AgentConnection {
  StreamController<WireEvent>? _run;

  /// Every input so far, oldest first.
  final inputs = <RunInput>[];

  /// Whether a session listens to the current run.
  bool get isListening => _run?.hasListener ?? false;

  @override
  Stream<WireEvent> run(RunInput input) {
    inputs.add(input);
    return (_run = StreamController<WireEvent>(sync: true)).stream;
  }

  /// Sends [json] as an event of the current run.
  void send(Map<String, Object?> json) => _run!.add(WireEvent.fromJson(json));
}

/// A `STATE_DELTA` that sets the whole draft, as ag-ui-adk sends it.
Map<String, Object?> draftDelta(OrderDraft draft) => {
  'type': 'STATE_DELTA',
  'delta': [
    {'op': 'add', 'path': '/order', 'value': draft.toJson()},
  ],
};
