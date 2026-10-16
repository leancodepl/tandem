import 'package:meta/meta.dart';
import 'package:tandem/src/tools/tool.dart';
import 'package:tandem/src/tools/tool_args.dart';

/// One entry of the timeline: what the user sees of a session, in order.
@immutable
sealed class TimelineItem {
  const TimelineItem(this.id);

  /// Stable across views, so it can be used as a widget key.
  final String id;
}

/// A message the user sent.
final class UserMessage extends TimelineItem {
  /// Creates the item. The session creates them; public for widget tests.
  const UserMessage(super.id, {required this.text, this.isQueued = false});

  /// The text.
  final String text;

  /// Whether it was sent during a run and waits to go out with the next one.
  final bool isQueued;
}

/// Text from the agent. While [isStreaming], [text] grows as it arrives.
final class AgentMessage extends TimelineItem {
  /// Creates the item. The session creates them; public for widget tests.
  const AgentMessage(super.id, {required this.text, this.isStreaming = false});

  /// The text so far.
  final String text;

  /// Whether more text may still arrive.
  final bool isStreaming;
}

/// A call of a tool or of an agent tool, for a line such as "Searching the
/// catalog..." in the timeline.
final class ToolActivity extends TimelineItem {
  /// Creates the item. The session creates them; public for widget tests.
  const ToolActivity(
    super.id, {
    required this.toolName,
    required this.label,
    required this.status,
    required this.runsInApp,
  });

  /// The name of the tool.
  final String toolName;

  /// The text to show: [Tool.label] for a tool, `TandemOptions.toolLabels`
  /// for an agent tool, otherwise the name in words.
  final String label;

  /// Whether it is running, succeeded or failed.
  final ToolActivityStatus status;

  /// `true` for a tool, which runs in the app; `false` for an agent tool,
  /// which runs on the agent's side.
  final bool runsInApp;
}

/// The status of a [ToolActivity].
enum ToolActivityStatus {
  /// Called, no result yet.
  running,

  /// Finished with a result. For an agent tool, the agent sent its result;
  /// Tandem does not read it, so a result that reports an error shows as
  /// succeeded too.
  succeeded,

  /// The tool threw, its arguments were invalid, or the run failed or was
  /// stopped before it finished.
  failed,
}

/// The user's decision point for one call of a tool with
/// [Tool.needsApproval]: the agent proposes, the user approves or rejects.
///
/// The request carries its own actions, so an approval card needs nothing
/// but the request:
///
/// ```dart
/// FilledButton(
///   onPressed: request.canApprove ? request.approve : null,
///   child: const Text('Place order'),
/// )
/// ```
final class ApprovalRequest extends TimelineItem {
  /// Creates the item. The session creates them; public for widget tests.
  const ApprovalRequest(
    super.id, {
    required this.toolName,
    required this.label,
    required this.args,
    required this.status,
    required Future<void> Function() onApprove,
    required Future<void> Function() onReject,
    this.result,
    this.failure,
  }) : _onApprove = onApprove,
       _onReject = onReject;

  /// The name of the tool.
  final String toolName;

  /// The text to show, as for [ToolActivity.label].
  final String label;

  /// The arguments exactly as the agent proposed them.
  final ToolArgs args;

  /// Where the request is.
  final ApprovalStatus status;

  /// What the tool returned, once [ApprovalStatus.executed].
  final Object? result;

  /// Why the tool failed, once [ApprovalStatus.failed].
  final String? failure;

  final Future<void> Function() _onApprove;
  final Future<void> Function() _onReject;

  /// Whether [approve] does anything: only while [ApprovalStatus.pending].
  ///
  /// While it is `true`, the live shared state equals the state at the
  /// proposal, so a card can render the live state as what the user
  /// approves.
  bool get canApprove => status == ApprovalStatus.pending;

  /// Whether the shared state changed after the proposal, so the request can
  /// no longer be approved. A card should say something like "The details
  /// changed, ask the assistant again".
  bool get isStale => status == ApprovalStatus.stale;

  /// Whether [reject] does anything: while pending or stale.
  bool get canReject =>
      status == ApprovalStatus.pending || status == ApprovalStatus.stale;

  /// Approves the call: re-checks the shared state, runs the tool and tells
  /// the agent the outcome in a follow-up run.
  ///
  /// Does nothing unless the request is still pending, so double taps are
  /// harmless. Completes when the tool has run, not when the agent has
  /// answered.
  Future<void> approve() => canApprove ? _onApprove() : Future.value();

  /// Rejects the call and tells the agent in a follow-up run. Does nothing
  /// unless the request is pending or stale.
  Future<void> reject() => canReject ? _onReject() : Future.value();
}

/// The status of an [ApprovalRequest].
enum ApprovalStatus {
  /// Waiting for the user; can be approved.
  pending,

  /// The shared state changed after the proposal. It can no longer be
  /// approved, even if the values are changed back, but it can be rejected.
  /// If the user sends a message instead, the agent is told the state
  /// changed.
  ///
  /// A request starts stale when the user changed the state during the run
  /// that proposed it, because the agent proposed without seeing that edit.
  stale,

  /// Approved; the tool is running.
  executing,

  /// Approved, and the tool returned.
  executed,

  /// Approved, but the tool threw.
  failed,

  /// The user rejected it.
  rejected,

  /// The user sent a message while it was open, and the agent was told:
  /// dismissed while it was pending, or invalidated because the state
  /// changed while it was stale. A message sent during the run that
  /// proposes it counts as sent while it was pending.
  ///
  /// Also the request of a run that was stopped or failed: the agent is
  /// told it was cancelled.
  dismissed,
}
