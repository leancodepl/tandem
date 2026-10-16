import 'dart:convert';

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

  /// The run ended with an error, or the app's agent list threw.
  runFailed,

  /// The run broke off; the next message starts a new conversation.
  connectionLost,
}

/// A line from Tandem itself, not from the user or the agent.
final class const ChatNotice(final ChatNoticeKind kind) extends ChatItem {
  /// A notice of [kind].
  this;
}

/// What became of an [ApprovalRequest].
enum ApprovalStatus() {
  /// It waits for the user.
  pending,

  /// The user approved it.
  approved,

  /// The user rejected it.
  rejected,

  /// What the agent sees changed after it showed, so it can no longer be
  /// approved.
  invalidated,

  /// The user sent a message instead of deciding.
  cancelled,
}

/// A call of a method listed with `.callsWithApproval`. The method runs only
/// once the user approves it.
final class const ApprovalRequest(
  /// The id of the call in the AG-UI thread.
  final String toolCallId,

  /// The method's name in snake_case.
  final String tool,

  /// The method's doc comment.
  final String description,
  final String _arguments, {

  /// What became of the request.
  final ApprovalStatus status = .pending,
}) extends ChatItem {
  /// The agent called [tool] in the call [toolCallId], with its arguments as
  /// the JSON it sent.
  this;

  /// The arguments the agent sent. They are decoded again on every read, so
  /// changing the map changes nothing the method gets.
  Map<String, Object?> get arguments =>
      jsonDecode(_arguments) as Map<String, Object?>;

  /// This request with [status].
  ApprovalRequest withStatus(ApprovalStatus status) => ApprovalRequest(
    toolCallId,
    tool,
    description,
    _arguments,
    status: status,
  );
}
