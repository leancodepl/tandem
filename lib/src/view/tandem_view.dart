import 'package:meta/meta.dart';
import 'package:tandem/src/view/agent_marks.dart';
import 'package:tandem/src/view/tandem_error.dart';
import 'package:tandem/src/view/timeline.dart';

/// Everything the UI shows about a session, as one immutable value.
///
/// It is not generic: the shared state stays in the screen's own state
/// holder, so with `tandem_bloc` the view is read with
/// `context.watch<TandemCubit>().state`, without type arguments.
@immutable
final class TandemView {
  /// Creates a view. The session creates them; public for widget tests.
  const TandemView({
    this.timeline = const [],
    this.isRunning = false,
    this.marks = AgentMarks.none,
    this.error,
  });

  /// The view of a new session: empty and idle.
  static const initial = TandemView();

  /// User messages, agent messages, tool activity and approval requests, in
  /// the order they happened.
  final List<TimelineItem> timeline;

  /// Whether a run is in progress, including automatic follow-up runs.
  final bool isRunning;

  /// Which leaves of the shared state the agent wrote last.
  final AgentMarks marks;

  /// Why the last run failed. Cleared when the next run starts.
  final TandemError? error;

  /// The approval requests still waiting for the user: pending or stale.
  List<ApprovalRequest> get openApprovals => [
    for (final item in timeline)
      if (item is ApprovalRequest && item.canReject) item,
  ];
}
