import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/protocol/run_input.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/view_tool.dart';

/// The calls of one turn of the agent, from the run that made them until
/// their answers go out with the next run. The calls that need approval wait
/// for the user one at a time, and the turn keeps what the agent saw when it
/// asked.
final class Turn(final List<ToolCall> calls) {
  SeesSnapshot? _seen;

  /// What the agent saw when it asked for approval, once the calls without
  /// approval ran. Null until the turn asks.
  SeesSnapshot? get seen => _seen;

  /// The first call still waiting for a decision once the turn asks.
  ToolCall? get next =>
      _seen == null ? null : calls.where(_undecided).firstOrNull;

  /// Whether the turn has calls and every one has an answer, so the answers
  /// can go to the agent.
  bool get answered =>
      calls.isNotEmpty && calls.every((call) => call.answer != null);

  /// Whether the answers go to the agent now, in a run of their own: the
  /// turn is answered, and not every call drew a view that shows, which the
  /// agent already followed with its text. Those answers go with the next
  /// message.
  bool get answersDue =>
      answered &&
      calls.any(
        (call) => call.tool != ViewTool.name || call.answer?.status != .shown,
      );

  /// The tool messages that answer the calls, once the undecided ones were
  /// cancelled. Only an approved method that still runs has no answer then,
  /// and the session sends none while one runs.
  List<AgUiMessage> get answers {
    assert(answered || calls.isEmpty, 'An approved method still runs.');
    return [
      for (final call in calls)
        AgUiMessage.toolResult(
          id: call.answerId,
          toolCallId: call.id,
          content: .text((call.answer ?? ToolAnswer.cancelled).content),
        ),
    ];
  }

  /// The calls without an answer wait for the user, one at a time through
  /// [next], and keep [seen].
  void ask(SeesSnapshot seen) => _seen = seen;

  /// Applies the decision to every call still waiting for an answer or approval.
  void decideUndecided(ApprovalStatus status) {
    for (final call in calls.where(_undecided)) {
      call.decide(status);
    }
  }

  /// Freezes the arguments of the calls that may ask the user, answering
  /// those that cannot. The session takes the turn's snapshot afterwards.
  void freezeArguments(AgentListing seen) {
    for (final call in calls.where(_undecided)) {
      if (call.freeze(seen) case final answer?) {
        call.answerWith(answer);
      }
    }
  }

  /// Refuses the undecided calls of a screen that takes no approvals.
  void refuseApprovals() {
    final refused = calls.where(_undecided).toList();
    for (final call in refused) {
      call.answerWith(ToolAnswer.noApprovals);
    }
    if (kDebugMode) {
      for (final call in refused) {
        report(
          StateError(
            '${call.tool} needs approval, but this screen has approvals: '
            '.none().',
          ),
          .current,
        );
      }
    }
  }

  static bool _undecided(ToolCall call) =>
      call.answer == null && !call.approved;
}
