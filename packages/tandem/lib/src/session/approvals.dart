import 'package:flutter/widgets.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// Gets [request] when it shows, with the context of the `TandemScope`, which
/// is above the session's `TandemSessionScope`. It decides with
/// `session.approve` or `session.reject`.
typedef ApprovalCallback = Future<void> Function(
  BuildContext context,
  ApprovalRequest request,
  TandemSession session,
);

/// How a screen asks the user to approve a call of a method listed with
/// `.callsWithApproval`.
sealed class const TandemApprovals() {
  /// Tandem calls [callback] for each request when it shows, one at a time,
  /// for example to open a dialog. A request it leaves undecided stays
  /// pending until the user's next message cancels it.
  const factory callback(ApprovalCallback callback) = ApprovalsByCallback;

  /// The UI draws requests itself, from `session.items` or from the status
  /// `AwaitingApproval`.
  const factory fromState() = ApprovalsFromState;

  /// The screen never asks. A call that needs approval is refused to the
  /// agent and reported in debug.
  const factory none() = NoApprovals;
}

final class const ApprovalsByCallback(final ApprovalCallback callback)
    extends TandemApprovals;

final class const ApprovalsFromState() extends TandemApprovals;

final class const NoApprovals() extends TandemApprovals;
