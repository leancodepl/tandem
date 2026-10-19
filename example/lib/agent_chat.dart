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

  /// A message that an empty chat sends with one tap.
  final String? suggestion,
}) extends StatefulWidget {
  @override
  State<AgentChat> createState() => _AgentChatState();
}

final class _AgentChatState() extends State<AgentChat> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _newestItem = GlobalKey();
  (TandemSession, String)? _shownCard;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = TandemSessionScope.of(context);
    if (session.items.lastOrNull case ApprovalRequest(:final toolCallId)
        when _shownCard != (session, toolCallId)) {
      _shownCard = (session, toolCallId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNewestCard());
    }
  }

  void _showNewestCard({bool jumped = false}) {
    if (!mounted) {
      return;
    }
    if (_newestItem.currentContext case final card?) {
      // In the reversed list, 1 shows a card taller than the chat from its top.
      Scrollable.ensureVisible(card, alignment: 1);
    } else if (!jumped && _scrollController.hasClients) {
      // The list does not build a card far below what the reader sees.
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showNewestCard(jumped: true),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
            child: switch (items) {
              [] => _EmptyChat(widget.suggestion, session),
              // Reversed, so that the newest item stays in view.
              _ => ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const .all(12),
                itemCount: items.length,
                itemBuilder: (context, index) => KeyedSubtree(
                  key: index == 0 ? _newestItem : null,
                  child: _Item(
                    items[items.length - 1 - index],
                    session,
                    widget.approvalBuilder,
                  ),
                ),
              ),
            },
          ),
          _Progress(session.status),
          _InputRow(session, _messageController),
        ],
      ),
    );
  }
}

final class const _EmptyChat(
  final String? suggestion,
  final TandemSession session,
) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const .all(20),
      child: switch (suggestion) {
        final text? => OutlinedButton(
          onPressed: () => session.send(text),
          child: Padding(
            padding: const .symmetric(vertical: 12),
            child: Text(text, textAlign: .center),
          ),
        ),
        null => const Text('Ask the agent to help with this screen.'),
      },
    ),
  );
}

final class const _Progress(final SessionStatus status)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      Idle() || AwaitingApproval() || Stopping() => null,
      Thinking() => 'Thinking…',
      Calling() => 'Applying the change…',
    };

    return switch (text) {
      final text? => Padding(
        padding: const .symmetric(horizontal: 16, vertical: 4),
        child: Text(text, style: context.textTheme.bodySmall),
      ),
      null => const SizedBox.shrink(),
    };
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
      child: Padding(
        padding: const .only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fromUser
                ? colors.primaryContainer
                : colors.surfaceContainerHigh,
            borderRadius: .circular(12),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              spacing: 4,
              children: [
                Text(
                  fromUser ? 'You' : 'Agent',
                  style: context.textTheme.labelSmall,
                ),
                Text(text),
                if (stopped)
                  Text('Stopped', style: context.textTheme.bodySmall),
              ],
            ),
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
  void _decide(void Function() decision) {
    try {
      decision();
    } on ApprovalNotPending {
      // The request changed as the user tapped. The card says so.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);

    return Card(
      margin: const .only(bottom: 12),
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            Text(switch (request.status) {
              .pending => 'Approval',
              .approved => 'Approved',
              .rejected => 'Rejected',
              .invalidated => 'What the agent saw changed. Ask it again.',
              .cancelled => 'Cancelled',
            }, style: context.textTheme.labelLarge),
            builder?.call(context, request) ??
                Column(
                  crossAxisAlignment: .start,
                  spacing: 4,
                  children: [
                    Text(request.description),
                    for (final MapEntry(:key, :value)
                        in request.arguments.entries)
                      Text('$key: $value'),
                  ],
                ),
            if (request.status == .pending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _decide(() => session.approve(request)),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: () => _decide(() => session.reject(request)),
                    child: const Text('Reject'),
                  ),
                ],
              ),
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
    final (String label, VoidCallback? onPressed) = switch (session.status) {
      Idle() || AwaitingApproval() => ('Send', _sendText),
      Thinking() || Calling(approved: false) => ('Stop', session.stop),
      Calling(approved: true) => ('Stop', null),
      Stopping() => ('Stopping…', null),
    };

    return Padding(
      padding: const .all(12),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              decoration: const InputDecoration(hintText: 'Message the agent'),
              textInputAction: .send,
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
