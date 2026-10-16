import 'package:flutter/material.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/session.dart';
import 'package:tandem/src/session_scope.dart';

const _width = 360.0;
const _gap = 8.0;

const _hint = 'Message';
const _send = 'Send';
const _stop = 'Stop';
const _stopping = 'Stopping…';
const _stopped = 'Stopped';
const _runFailed = 'The agent ran into a problem. Try again.';
const _connectionLost = 'Connection lost. Starting a new conversation.';
const _approve = 'Approve';
const _reject = 'Reject';
const _approved = 'Approved';
const _rejected = 'Rejected';
const _cancelled = 'Cancelled';
const _invalidated = 'The screen changed. Ask the agent again.';

/// Builds what an approval card shows above Tandem's own Approve and Reject.
typedef ApprovalBuilder = Widget Function(
  BuildContext context,
  ApprovalRequest request,
);

/// The chat of the user and the agent: its messages, the cards that ask for
/// approval, and the field to write in. It has its own width and background,
/// so it goes next to the screen, as in `Row(children: [OrderForm(),
/// TandemChat()])`.
final class const TandemChat({
  super.key,
  final ApprovalBuilder? approvalBuilder,
}) extends StatefulWidget {
  /// A chat of the closest `TandemScope`. A card shows what [approvalBuilder]
  /// builds for its request, or by default the method's description and
  /// arguments.
  this;

  @override
  State<TandemChat> createState() => _TandemChatState();
}

final class _TandemChatState() extends State<TandemChat> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    final items = session.items;
    return SizedBox(
      width: _width,
      child: Material(
        child: Column(
          children: [
            Expanded(
              // Reversed, so that the newest item stays in view.
              child: ListView.builder(
                reverse: true,
                padding: const .all(_gap),
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _show(items[items.length - 1 - index]),
              ),
            ),
            _InputRow(session, _text),
          ],
        ),
      ),
    );
  }

  Widget _show(ChatItem item) => switch (item) {
    UserMessage(:final text) => _Bubble(text, fromUser: true),
    AgentMessage(:final text, :final stopped) => _Bubble(
      text,
      stopped: stopped,
    ),
    ChatNotice(:final kind) => _Notice(kind),
    ApprovalRequest() => _ApprovalCard(item, widget.approvalBuilder),
  };
}

final class const _Bubble(
  final String text, {
  final bool fromUser = false,
  final bool stopped = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? .centerRight : .centerLeft,
      child: Card(
        color: fromUser ? colors.primaryContainer : colors.surfaceContainer,
        child: Padding(
          padding: const .all(_gap),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(text),
              if (stopped)
                Text(_stopped, style: Theme.of(context).textTheme.bodySmall),
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
    padding: const .all(_gap),
    child: Text(
      switch (kind) {
        .stopped => _stopped,
        .runFailed => _runFailed,
        .connectionLost => _connectionLost,
      },
      textAlign: .center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

final class const _ApprovalCard(
  final ApprovalRequest request,
  final ApprovalBuilder? builder,
) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = TandemSessionScope.of(context);
    // The session ignores both while a method of the turn runs.
    final idle = !session.isRunning;
    return Card(
      child: Padding(
        padding: const .all(_gap),
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
              .pending => Row(
                spacing: _gap,
                children: [
                  FilledButton(
                    onPressed: idle ? () => session.approve(request) : null,
                    child: const Text(_approve),
                  ),
                  OutlinedButton(
                    onPressed: idle ? () => session.reject(request) : null,
                    child: const Text(_reject),
                  ),
                ],
              ),
              .approved => const Text(_approved),
              .rejected => const Text(_rejected),
              .invalidated => const Text(_invalidated),
              .cancelled => const Text(_cancelled),
            },
          ],
        ),
      ),
    );
  }
}

final class const _InputRow(
  final TandemSession session,
  final TextEditingController text,
) extends StatelessWidget {
  void _sendText() {
    session.send(text.text);
    text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final (String label, VoidCallback? onPressed) = switch (session) {
      TandemSession(isStopping: true) => (_stopping, null),
      TandemSession(isRunning: true) => (_stop, session.stop),
      _ => (_send, _sendText),
    };
    return Padding(
      padding: const .all(_gap),
      child: Row(
        spacing: _gap,
        children: [
          Expanded(
            child: TextField(
              controller: text,
              decoration: const InputDecoration(hintText: _hint),
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
