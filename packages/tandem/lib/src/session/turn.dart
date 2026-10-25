import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';

/// The calls of one turn of the agent, from the run that made them until
/// their answers go out with the next run. The calls that need approval wait
/// for the user one at a time, and the turn keeps what the agent saw when it
/// asked.
final class Turn(final List<ToolCall> calls) {
  SeesSnapshot? _seen;

  /// What the agent saw when it asked for approval, once the calls without
  /// approval ran. Null until the turn asks.
  SeesSnapshot? get seen => _seen;

  /// The request that waits for the user.
  ApprovalRequest? get awaited =>
      calls.where((call) => call.pending).firstOrNull?.request;

  /// Whether a call waits for the user.
  bool get waitsForUser => _seen != null && calls.any(_waits);

  /// Whether the turn has calls and every one has an answer, so the answers
  /// can go to the agent.
  bool get answered =>
      calls.isNotEmpty && calls.every((call) => call.answer != null);

  /// The tool messages that answer the calls. A call without an answer is
  /// `cancelled`.
  List<AgUiMessage> get answers => [
    for (final call in calls)
      AgUiMessage.toolAnswer(
        call.id,
        (call.answer ?? ToolAnswer.cancelled).content,
      ),
  ];

  /// The calls without an answer wait for the user, one at a time through
  /// [next], and keep [seen].
  void ask(SeesSnapshot seen) => _seen = seen;

  /// Shows the next call that waits, unless a request shows already, and
  /// returns its request.
  ApprovalRequest? next() {
    if (!waitsForUser || awaited != null) {
      return null;
    }
    return calls.firstWhere(_waits).ask();
  }

  bool isPending(ApprovalRequest request) => _pendingCall(request) != null;

  /// Approves [request] and returns its call, to run. Returns null when it is
  /// approved already, and throws an [ApprovalNotPending] when it was
  /// rejected, cancelled or invalidated.
  ToolCall? approve(ApprovalRequest request) => _decide(request, .approved);

  /// Rejects [request] and cancels the rest of the turn, so the agent plans
  /// again. Returns its call, or null when it is rejected already. Throws an
  /// [ApprovalNotPending] when it was approved, cancelled or invalidated.
  ToolCall? reject(ApprovalRequest request) {
    final call = _decide(request, .rejected);
    if (call != null) {
      cancelWaiting();
    }
    return call;
  }

  /// Invalidates every call that waits for the user and returns them.
  List<ToolCall> invalidateWaiting() => _decideWaiting(.invalidated);

  /// Cancels every call that waits, as when the user writes instead of
  /// deciding, and returns them.
  List<ToolCall> cancelWaiting() => _decideWaiting(.cancelled);

  /// Refuses every call that waits, for a screen that takes no approvals,
  /// and returns them.
  List<ToolCall> refuseWaiting() => [
    for (final call in calls.where(_waits).toList())
      call..answer = ToolAnswer.noApprovals,
  ];

  ToolCall? _decide(ApprovalRequest request, ApprovalStatus decision) {
    if (request.status == decision) {
      return null;
    }
    final call = _pendingCall(request);
    if (call == null) {
      throw ApprovalNotPending(request);
    }
    call.decide(decision);
    return call;
  }

  ToolCall? _pendingCall(ApprovalRequest request) => calls
      .where((call) => call.pending && call.id == request.toolCallId)
      .firstOrNull;

  List<ToolCall> _decideWaiting(ApprovalStatus status) {
    final waiting = calls.where(_waits).toList();
    for (final call in waiting) {
      call.decide(status);
    }
    return waiting;
  }

  static bool _waits(ToolCall call) => call.answer == null && !call.approved;
}
