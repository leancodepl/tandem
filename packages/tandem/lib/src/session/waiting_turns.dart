import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';

/// The turns whose calls may wait for the user: the in-app agent's turn,
/// then one turn for each other caller, in the order they asked. One request
/// shows at a time, the in-app agent's first.
final class WaitingTurns() {
  var _agent = Turn(const []);
  final _others = <Caller, Turn>{};
  ToolCall? _lastShown;

  Iterable<Turn> get _turns => [_agent, ..._others.values];

  bool get agentAnswersDue => _agent.answersDue;

  Turn startAgentTurn(List<ToolCall> calls) => _agent = Turn(calls);

  Turn closeAgentTurn() {
    final turn = _agent;
    startAgentTurn(const []);
    turn.decideUndecided(.cancelled);
    return turn;
  }

  ToolCall? get _pending => switch (_lastShown) {
    final call? when call.pending => call,
    _ => null,
  };

  ApprovalRequest? get shown => _pending?.request;

  bool isPending(ApprovalRequest request) => shown?.key == request.key;

  ToolCall? decide(ApprovalRequest request, ApprovalStatus decision) {
    if (request.status == decision) return null;
    final call = _pending;
    if (call == null || call.request?.key != request.key) {
      throw ApprovalNotPending(request);
    }
    call.decide(decision);
    if (decision == .rejected && call.caller == .inAppAgent) {
      _agent.decideUndecided(.cancelled);
    }
    return call;
  }

  /// Whether a call waits for the user, shown or not.
  bool get waitsForUser => _turns.any((turn) => turn.next != null);

  /// The last call of [caller] that asked the user, null before the first.
  ToolCall? lastAsked(Caller caller) => _others[caller]?.calls.singleOrNull;

  /// [call] of another caller than the in-app agent waits for the user after
  /// the turns that wait already, for what the agent sees as [seen].
  void ask(ToolCall call, SeesSnapshot seen) {
    _others.remove(call.caller);
    _others[call.caller] = Turn([call])..ask(seen);
  }

  /// Shows the next call that waits, unless a request shows already, and
  /// returns its request.
  ApprovalRequest? showNext(List<ChatItem> chat) {
    if (shown != null) {
      return null;
    }
    _lastShown = _turns.map((turn) => turn.next).nonNulls.firstOrNull;
    return _lastShown?.ask(chat);
  }

  /// Returns whether any call lost its approval because the screen changed.
  bool invalidateUnlike(SeesSnapshot seen) {
    var invalidated = false;
    for (final turn in _turns) {
      if (turn.next != null && turn.seen != seen) {
        turn.decideUndecided(.invalidated);
        invalidated = true;
      }
    }
    return invalidated;
  }

  void cancelShownOfOthers() {
    final call = _pending;
    if (call != null && call.caller != .inAppAgent) call.decide(.cancelled);
  }

  void cancelAll() {
    for (final turn in _turns) {
      turn.decideUndecided(.cancelled);
    }
  }
}
