import 'package:example/agent_chat.dart';
import 'package:example/desk/ui/agent_workspace.dart';
import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/order.dart';
import 'package:example/order_cubit.dart';
import 'package:example/order_messages.dart';
import 'package:example/order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

final class const FirebaseOrderApp({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tandem with Firebase AI',
    debugShowCheckedModeBanner: false,
    theme: deskTheme,
    home: BlocProvider(
      create: (context) => OrderCubit(orders: Orders()),
      child: TandemScope.connected(
        surface: (context) => context.read<OrderCubit>(),
        connection: connection,
        approvals: const .fromState(),
        onEvent: _showFirebaseOrderMessages,
        child: const Scaffold(
          body: SafeArea(
            child: AgentWorkspace(
              title: 'Order draft',
              chat: AgentChat(
                suggestion: 'Add 15 VM-27Q monitors, then place the order.',
              ),
              child: OrderForm(),
            ),
          ),
        ),
      ),
    ),
  );
}

void _showFirebaseOrderMessages(
  BuildContext context,
  TandemEvent event,
  TandemSession session,
) {
  if (event case RunFailed(code: FirebaseErrorCode.incompatibleHistory)) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Start a new conversation to keep editing this draft.',
          ),
          action: SnackBarAction(
            label: 'New conversation',
            onPressed: session.startOver,
          ),
        ),
      );
    return;
  }
  showOrderMessages(context, event, session);
}
