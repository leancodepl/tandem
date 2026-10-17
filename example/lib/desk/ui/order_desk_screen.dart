import 'package:example/desk/customers.dart';
import 'package:example/desk/order_desk_cubit.dart';
import 'package:example/desk/orders.dart';
import 'package:example/desk/ui/highlights.dart';
import 'package:example/desk/ui/order_form.dart';
import 'package:example/desk/ui/order_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

final _agent = Uri.parse('http://localhost:8000/agent');

/// The width of the chat beside the form.
const _chatWidth = 360.0;

/// The hairline between the form and the chat.
const _dividerWidth = 1.0;

const _gap = 16.0;
const _headerPadding = EdgeInsets.fromLTRB(_gap, _gap, _gap, 0);
const _title = 'Order desk';
const _titleSeparator = '  ·  ';

/// The order desk: the order form under a header, with the chat of the agent
/// beside it.
///
/// It talks to the agent at `localhost:8000`, or over [connection], such as
/// a `ScriptedAgent` in a test.
final class const OrderDeskScreen({
  super.key,
  final AgentConnection? connection,
}) extends StatefulWidget {
  @override
  State<OrderDeskScreen> createState() => _OrderDeskScreenState();
}

final class _OrderDeskScreenState() extends State<OrderDeskScreen> {
  final _highlights = Highlights();

  @override
  void dispose() {
    _highlights.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = HighlightScope(
      highlights: _highlights,
      child: Scaffold(
        body: SafeArea(
          child: Row(
            // The form starts at the top and does not move as it fills.
            crossAxisAlignment: .stretch,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    Padding(padding: _headerPadding, child: _Header()),
                    Expanded(child: OrderForm()),
                  ],
                ),
              ),
              const VerticalDivider(width: _dividerWidth),
              SizedBox(
                width: _chatWidth,
                child: TandemChat(
                  approvalBuilder: (context, request) => const OrderSummary(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return BlocProvider(
      create: (context) => OrderDeskCubit(
        catalog: .demo(),
        customers: .demo(),
        orders: Orders(),
      ),
      child: switch (widget.connection) {
        final connection? => TandemScope<OrderDeskCubit>.connected(
          connection: connection,
          onAgentCall: (context, call) => _highlights.onAgentCall(call),
          child: screen,
        ),
        null => TandemScope<OrderDeskCubit>(
          agent: _agent,
          onAgentCall: (context, call) => _highlights.onAgentCall(call),
          child: screen,
        ),
      },
    );
  }
}

/// The title of the screen, with the customer once the order has one.
final class const _Header() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final customer = context.select<OrderDeskCubit, Customer?>(
      (cubit) => cubit.order.customer,
    );
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        text: _title,
        children: [
          if (customer != null)
            TextSpan(
              text: '$_titleSeparator${customer.name}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      style: theme.textTheme.titleLarge,
    );
  }
}
