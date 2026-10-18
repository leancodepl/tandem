import 'package:tandem/src/chat/chat_item.dart';

/// What a session does now. Stop is available while it is [Thinking] or
/// [Calling] a method the user did not approve. Two statuses that say the
/// same are equal, so `select` and `distinct` see only real changes.
sealed class const SessionStatus();

/// No run is open and no approval request waits.
final class const Idle() extends SessionStatus;

/// A run is open and the agent's answer streams in.
final class const Thinking() extends SessionStatus;

/// A listed method the agent called runs.
final class const Calling(
  /// The method's name in snake_case.
  final String tool, {

  /// The user approved the call, so it runs to its end and cannot be
  /// stopped.
  required final bool approved,
}) extends SessionStatus {
  @override
  bool operator ==(Object other) =>
      other is Calling && other.tool == tool && other.approved == approved;

  @override
  int get hashCode => Object.hash(tool, approved);
}

/// No run is open and [request] waits for the user. The other requests of
/// the turn show after it.
final class const AwaitingApproval(final ApprovalRequest request)
    extends SessionStatus {
  @override
  bool operator ==(Object other) =>
      other is AwaitingApproval && other.request == request;

  @override
  int get hashCode => request.hashCode;
}

/// The user stopped the open run, which is read to its end. A new message
/// waits for it.
final class const Stopping() extends SessionStatus;
