import 'package:example/recipes/approval_dialog/reply_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// A reply to a customer that the agent writes. It sends the reply only
/// after the user approves it in a dialog.
final class const ReplyScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ReplyCubit(),
    child: TandemScope.connected(
      surface: (context) => context.read<ReplyCubit>(),
      connection: connection,
      approvals: const .callback(_confirmSend),
      onEvent: (context, event, session) {
        if (event case RunFailed() || ConnectionLost()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The agent did not answer. Try again.'),
            ),
          );
        }
      },
      child: const Scaffold(body: _ReplyView()),
    ),
  );
}

Future<void> _confirmSend(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
) async {
  final reply = context.read<ReplyCubit>().reply;
  final send = await showDialog<bool>(
    context: context,
    builder: (context) => _SendDialog(reply),
  );
  try {
    if (send ?? false) {
      session.approve(request);
    } else {
      session.reject(request);
    }
  } on ApprovalNotPending {
    // The reply changed, or the screen closed, while the dialog showed.
  }
}

final class const _SendDialog(final String reply) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Send this reply?'),
    content: Text(reply),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Send'),
      ),
    ],
  );
}

final class const _ReplyView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ReplyCubit>();
    final session = TandemSessionScope.of(context);

    return ListView(
      padding: const .all(16),
      children: [
        const Text('Customer: Where is my parcel? I ordered it last week.'),
        const SizedBox(height: 16),
        Text(cubit.reply.isEmpty ? 'No reply yet.' : cubit.reply),
        if (cubit.sent) const Text('Sent'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: session.status is Idle
              ? () => session.send('Answer the customer and send the reply.')
              : null,
          child: const Text('Answer with the agent'),
        ),
      ],
    );
  }
}
