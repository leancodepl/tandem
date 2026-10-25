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

  /// The request that shows and waits for the user.
  ApprovalRequest? get shown =>
      calls.where((call) => call.pending).firstOrNull?.request;

  /// Whether a call waits for the user, shown or not.
  bool get waitsForUser => _seen != null && calls.any(_undecided);

  /// Whether the turn has calls and every one has an answer, so the answers
  /// can go to the agent.
  bool get answered =>
      calls.isNotEmpty && calls.every((call) => call.answer != null);

  /// The tool messages that answer the calls, once the undecided ones were
  /// cancelled. Only an approved method that still runs has no answer then,
  /// and the session sends none while one runs.
  List<AgUiMessage> get answers {
    assert(answered || calls.isEmpty, 'An approved method still runs.');
    return [
      for (final call in calls)
        AgUiMessage.toolAnswer(
          call.id,
          (call.answer ?? ToolAnswer.cancelled).content,
        ),
    ];
  }

  /// The calls without an answer wait for the user, one at a time through
  /// [next], and keep [seen].
  void ask(SeesSnapshot seen) => _seen = seen;

  /// Shows the next call that waits, unless a request shows already, and
  /// returns its request.
  ApprovalRequest? next() {
    if (!waitsForUser || shown != null) {
      return null;
    }
    return calls.firstWhere(_undecided).ask();
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
      cancelUndecided();
    }
    return call;
  }

  /// Invalidates every call that has no answer and was not approved, and
  /// returns them.
  List<ToolCall> invalidateUndecided() => _decideUndecided(.invalidated);

  /// Cancels every call that has no answer and was not approved, as when the
  /// user writes instead of deciding or the run was stopped, and returns
  /// them.
  List<ToolCall> cancelUndecided() => _decideUndecided(.cancelled);

  /// Refuses every call that has no answer and was not approved, for a
  /// screen that takes no approvals, and returns them.
  List<ToolCall> refuseUndecided() => [
    for (final call in calls.where(_undecided).toList())
      call..answerWith(ToolAnswer.noApprovals),
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

  List<ToolCall> _decideUndecided(ApprovalStatus status) {
    final undecided = calls.where(_undecided).toList();
    for (final call in undecided) {
      call.decide(status);
    }
    return undecided;
  }

  static bool _undecided(ToolCall call) =>
      call.answer == null && !call.approved;
}
