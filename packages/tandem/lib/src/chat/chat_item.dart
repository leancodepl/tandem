/// One entry of the chat. Items are immutable: the session replaces an item
/// to change it.
sealed class const ChatItem() {
  /// For the kinds of items below.
  this;
}

/// A message the user sent.
final class const UserMessage(final String text) extends ChatItem {
  /// The user sent [text].
  this;
}

/// Text the agent said in one message of a run.
final class const AgentMessage(final String text, {final bool stopped = false})
    extends ChatItem {
  /// The agent said [text]; [stopped] when the user stopped the run after it.
  this;
}

/// Why a [ChatNotice] is in the chat.
enum ChatNoticeKind() {
  /// The user stopped a run before the agent said anything.
  stopped,

  /// The run ended with an error.
  runFailed,

  /// The run broke off; the next message starts a new conversation.
  connectionLost,
}

/// A line from Tandem itself, not from the user or the agent.
final class const ChatNotice(final ChatNoticeKind kind) extends ChatItem {
  /// A notice of [kind].
  this;
}
