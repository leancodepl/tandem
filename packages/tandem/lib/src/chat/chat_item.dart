import 'dart:convert';

/// Immutable: the session replaces an item to change it.
sealed class const ChatItem();

final class const UserMessage(final String text) extends ChatItem;

final class const AgentMessage(
  final String text, {

  /// The user stopped the run after this text.
  final bool stopped = false,
}) extends ChatItem;

enum ChatNoticeKind() {
  /// The user stopped a run before the agent said anything.
  stopped,

  /// The run ended with an error, or the app's agent list threw.
  runFailed,

  /// The run broke off; the next message starts a new conversation.
  connectionLost,
}

/// A line from Tandem itself, not from the user or the agent.
final class const ChatNotice(final ChatNoticeKind kind) extends ChatItem;

enum ApprovalStatus() {
  pending,
  approved,
  rejected,

  /// A value listed with `.sees` changed after the agent asked, so it can no
  /// longer be approved.
  invalidated,

  /// The user sent a message instead of deciding.
  cancelled,
}

/// A call of a method listed with `.callsWithApproval`.
final class const ApprovalRequest({
  required final String toolCallId,

  /// The method's name in snake_case.
  required final String tool,

  /// The method's doc comment. The default card shows it above the
  /// arguments.
  required final String description,
  required final String _argumentsJson,
  final ApprovalStatus status = .pending,
}) extends ChatItem {
  /// Decoded again on every read, so changing the map changes nothing the
  /// method gets.
  Map<String, Object?> get arguments =>
      jsonDecode(_argumentsJson) as Map<String, Object?>;

  ApprovalRequest withStatus(ApprovalStatus status) => ApprovalRequest(
    toolCallId: toolCallId,
    tool: tool,
    description: description,
    argumentsJson: _argumentsJson,
    status: status,
  );
}
