import 'dart:convert';

import 'package:tandem/src/session/caller.dart';

/// Immutable: the session replaces an item to change it.
sealed class const ChatItem();

/// A message the user wrote, or one the app sent with `session.send` or
/// `session.wake`.
final class const UserMessage(
  final String text, {

  /// `session.wake` sent it, for the agent rather than the user, so a chat
  /// may hide it.
  final bool fromApp = false,
}) extends ChatItem;

/// One message of the agent. While the run streams it, the session replaces
/// it with a longer one in the same place.
final class const AgentMessage(
  final String text, {

  /// The user or the backend stopped the run after this text.
  final bool stopped = false,
}) extends ChatItem;

/// What a [ChatNotice] tells the user.
enum ChatNoticeKind() {
  /// The user or the backend stopped a run before the agent said anything.
  stopped,

  /// The run ended with an error, or the app's agent list threw. After a
  /// run Tandem cannot follow, such as one that ends with an interrupt, the
  /// next message starts a new conversation.
  runFailed,

  /// The run broke off; the next message starts a new conversation.
  connectionLost,

  /// The app called `session.startOver`; the agent no longer has the
  /// messages above.
  startedOver,
}

/// A line from Tandem itself, not from the user or the agent.
final class const ChatNotice(final ChatNoticeKind kind) extends ChatItem;

/// Where an [ApprovalRequest] stands. Only a [pending] one can be decided.
enum ApprovalStatus() {
  pending,

  /// The user approved it, and its method runs or ran.
  approved,

  /// The user rejected it. The in-app agent hears so with its next run, and
  /// a coding agent in its answer.
  rejected,

  /// A value listed with `.sees` changed after the call asked, so it can no
  /// longer be approved.
  invalidated,

  /// The user sent a message instead of deciding.
  cancelled,
}

/// A call of a method listed with `.callsWithApproval`.
final class const ApprovalRequest({
  /// The id of the call. It stays the same when the status changes, so a UI
  /// can key the request's card by it.
  required final String toolCallId,

  /// The method's name in snake_case.
  required final String tool,

  /// The method's doc comment, written for the agent. Show the user your
  /// own text, picked by [tool].
  required final String description,
  required final String _argumentsJson,
  final ApprovalStatus status = .pending,

  /// Who asked, so the card can say what happens next.
  final Caller caller = .inAppAgent,
}) extends ChatItem {
  /// Decoded again on every read, so changing the map changes nothing the
  /// method gets.
  Map<String, Object?> get arguments =>
      jsonDecode(_argumentsJson) as Map<String, Object?>;

  /// A copy with [status], as the session makes when it decides. A test can
  /// use it for a request in any status.
  ApprovalRequest withStatus(ApprovalStatus status) => ApprovalRequest(
    toolCallId: toolCallId,
    tool: tool,
    description: description,
    argumentsJson: _argumentsJson,
    status: status,
    caller: caller,
  );
}
