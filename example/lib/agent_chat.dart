import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

/// Builds what an approval card shows above Approve and Reject.
typedef ApprovalBuilder = Widget Function(
  BuildContext context,
  ApprovalRequest request,
);

/// The chat of the user and the agent: its messages, the cards that ask for
/// approval, and the field to write in. It uses only the public
/// [TandemSession], so an app can copy it and give it its own texts and look.
/// It needs a `TandemScope` above it, fills its parent and has its own
/// background. Next to the screen, give it a width, as in
/// `Row(children: [Expanded(child: OrderForm()),
/// SizedBox(width: 360, child: AgentChat())])`.
final class const AgentChat({
  super.key,

  /// Without it, a card shows the method's description and arguments.
  final ApprovalBuilder? approvalBuilder,
}) extends StatefulWidget {
  @override
  State<AgentChat> createState() => _AgentChatState();
}

final class _AgentChatState() extends State<AgentChat> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final items = session.items;

    return Material(
      child: Column(
        children: [
          Expanded(
            // Reversed, so that the newest item stays in view.
            child: ListView.builder(
              reverse: true,
              padding: const .all(8),
              itemCount: items.length,
              itemBuilder: (context, index) => _Item(
                items[items.length - 1 - index],
                session,
                widget.approvalBuilder,
              ),
            ),
          ),
          _InputRow(session, _messageController),
        ],
      ),
    );
  }
}

final class const _Item(
  final ChatItem item,
  final TandemSession session,
  final ApprovalBuilder? approvalBuilder,
) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (item) {
    UserMessage(:final text) => _Bubble(text, fromUser: true),
    AgentMessage(:final text, :final stopped) => _Bubble(
      text,
      stopped: stopped,
    ),
    ChatNotice(:final kind) => _Notice(kind),
    // A card of another call that lands at the same index gets a new state.
    final ApprovalRequest request => _ApprovalCard(
      request,
      approvalBuilder,
      key: ValueKey((session, request.toolCallId)),
    ),
  };
}

final class const _Bubble(
  final String text, {
  final bool fromUser = false,
  final bool stopped = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Align(
      alignment: fromUser ? .centerRight : .centerLeft,
      child: Card(
        color: fromUser ? colors.primaryContainer : colors.surfaceContainer,
        child: Padding(
          padding: const .all(8),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(text),
              if (stopped) Text('Stopped', style: context.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

final class const _Notice(final ChatNoticeKind kind) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .all(8),
    child: Text(
      switch (kind) {
        .stopped => 'Stopped',
        .runFailed => 'The agent ran into a problem. Try again.',
        .connectionLost => 'Connection lost. Starting a new conversation.',
      },
      textAlign: .center,
      style: context.textTheme.bodySmall,
    ),
  );
}

final class const _ApprovalCard(
  final ApprovalRequest request,
  final ApprovalBuilder? builder, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    // The session ignores both while a method of the turn runs.
    final canDecide = !session.isRunning;

    return Card(
      child: Padding(
        padding: const .all(8),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            builder?.call(context, request) ??
                Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(request.description),
                    for (final MapEntry(:key, :value)
                        in request.arguments.entries)
                      Text('$key: $value'),
                  ],
                ),
            switch (request.status) {
              .pending => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: canDecide
                        ? () => session.approve(request)
                        : null,
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: canDecide ? () => session.reject(request) : null,
                    child: const Text('Reject'),
                  ),
                ],
              ),
              .approved => const Text('Approved'),
              .rejected => const Text('Rejected'),
              .invalidated => const Text(
                'The screen changed. Ask the agent again.',
              ),
              .cancelled => const Text('Cancelled'),
            },
          ],
        ),
      ),
    );
  }
}

final class const _InputRow(
  final TandemSession session,
  final TextEditingController messageController,
) extends StatelessWidget {
  void _sendText() {
    session.send(messageController.text);
    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final (String label, VoidCallback? onPressed) = switch (session) {
      TandemSession(isStopping: true) => ('Stopping…', null),
      TandemSession(canStop: true) => ('Stop', session.stop),
      TandemSession(isRunning: true) => ('Stop', null),
      _ => ('Send', _sendText),
    };

    return Padding(
      padding: const .all(8),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              decoration: const InputDecoration(hintText: 'Message'),
              // Unlike onSubmitted, it leaves the focus in the field.
              onEditingComplete: _sendText,
            ),
          ),
          FilledButton(onPressed: onPressed, child: Text(label)),
        ],
      ),
    );
  }
}

extension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
