import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';

/// The calls of one turn of the agent, from the run that made them until
/// their answers go out with the next run. The calls that need approval wait
/// for the user, and the turn keeps what the agent saw when it asked.
final class Turn(final List<ToolCall> calls) {
  SeesSnapshot? _seen;

  /// What the agent saw when it asked for approval, once the calls without
  /// approval ran. Null until the turn asks.
  SeesSnapshot? get seen => _seen;

  /// Whether a call waits for the user.
  bool get waitsForUser => _seen != null && calls.any(_waits);

  /// Whether the turn has calls and every one has an answer, so the answers
  /// can go to the agent.
  bool get answered =>
      calls.isNotEmpty && calls.every((call) => call.answer != null);

  /// The tool messages that answer the calls. A call without an answer is
  /// `cancelled`.
  List<Map<String, Object?>> get answers => [
    for (final call in calls)
      toolAnswer(call.id, call.answer ?? ToolAnswer.cancelled),
  ];

  /// Asks the user about every call without an answer, which keeps [seen].
  /// Returns the requests to show.
  List<ApprovalRequest> ask(SeesSnapshot seen) {
    _seen = seen;
    return [
      for (final call in calls)
        if (_waits(call)) call.ask(),
    ];
  }

  /// Approves [request] and returns its call, to run. Null unless [request]
  /// is pending.
  ToolCall? approve(ApprovalRequest request) => _decide(request, .approved);

  /// Rejects [request] and returns its call. Null unless [request] is
  /// pending.
  ToolCall? reject(ApprovalRequest request) => _decide(request, .rejected);

  /// Invalidates every call that waits for the user and returns them.
  List<ToolCall> invalidateWaiting() => _decideWaiting(.invalidated);

  /// Cancels every call that waits, as when the user writes instead of
  /// deciding, and returns them.
  List<ToolCall> cancelWaiting() => _decideWaiting(.cancelled);

  ToolCall? _decide(ApprovalRequest request, ApprovalStatus status) {
    final call = calls
        .where((call) => call.pending && call.id == request.toolCallId)
        .firstOrNull;
    call?.decide(status);
    return call;
  }

  List<ToolCall> _decideWaiting(ApprovalStatus status) {
    final waiting = calls.where(_waits).toList();
    for (final call in waiting) {
      call.decide(status);
    }
    return waiting;
  }

  static bool _waits(ToolCall call) => call.answer == null && !call.approved;
}
