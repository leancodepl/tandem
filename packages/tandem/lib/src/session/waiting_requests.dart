import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';

/// The turns whose calls may wait for the user, and their requests in the
/// chat: the in-app agent's turn, then one turn per outside caller, in the
/// order they asked. One request shows at a time.
final class WaitingRequests(final List<ChatItem> _items) {
  var _agent = Turn(const []);
  final _outside = <Caller, Turn>{};

  /// The calls of the in-app agent's last run, until their answers go out.
  Turn get agent => _agent;

  /// The request that waits for the user now.
  ApprovalRequest? get shown =>
      _turns.map((turn) => turn.awaited).nonNulls.firstOrNull;

  /// Whether a call waits for the user, shown or not.
  bool get waitsForUser => _turns.any((turn) => turn.waitsForUser);

  ToolCall? lastAsked(Caller caller) => _outside[caller]?.calls.singleOrNull;

  /// The in-app agent's new turn; nothing of it waits yet.
  void openAgentTurn(List<ToolCall> calls) => _agent = Turn(calls);

  /// Cancels the in-app agent's calls that wait and returns its turn, for
  /// the answers. A new, empty turn follows it.
  Turn closeAgentTurn() {
    final closed = _agent;
    _cancel(closed);
    _agent = Turn(const []);
    return closed;
  }

  /// [call] waits for the user after the requests that wait already, for
  /// what the agent saw as [seen].
  void ask(Caller caller, ToolCall call, SeesSnapshot seen) {
    _outside.remove(caller);
    _outside[caller] = Turn([call])..ask(seen);
  }

  /// Shows the next request, the in-app agent's first, unless one shows
  /// already, and returns it.
  ApprovalRequest? showNext() {
    if (shown != null) {
      return null;
    }
    for (final turn in _turns) {
      if (turn.next() case final request?) {
        _items.add(request);
        return request;
      }
    }
    return null;
  }

  Turn turnOf(ApprovalRequest request) => _outside.values.firstWhere(
    (turn) => turn.calls.any((call) => call.id == request.toolCallId),
    orElse: () => _agent,
  );

  bool isAgentTurn(Turn turn) => identical(turn, _agent);

  /// The app may hold an older copy of [request], with an older status.
  ApprovalRequest latest(ApprovalRequest request) =>
      _items.whereType<ApprovalRequest>().lastWhere(
        (item) => item.toolCallId == request.toolCallId,
        orElse: () => request,
      );

  /// Puts the decided request of [call] in place of the one that showed.
  void showDecision(ToolCall call) {
    if (call.request case final decided?) {
      final shown = _items.indexWhere(
        (item) =>
            item is ApprovalRequest && item.toolCallId == decided.toolCallId,
      );
      _items[shown] = decided;
    }
  }

  /// Invalidates the waiting calls of every turn that saw other than
  /// [seen]. Returns whether one did.
  bool invalidate(SeesSnapshot seen) {
    final changed = [
      for (final turn in _turns)
        if (turn.waitsForUser && seen != turn.seen) turn,
    ];
    for (final turn in changed) {
      turn.invalidateWaiting().forEach(showDecision);
    }
    return changed.isNotEmpty;
  }

  /// Cancels the request of an outside caller that shows, as when the user
  /// writes instead of deciding.
  void cancelShownOutside() {
    for (final turn in _outside.values) {
      if (turn.awaited != null) {
        _cancel(turn);
      }
    }
  }

  /// Cancels every call that waits and forgets the in-app agent's turn.
  void cancelAll() {
    _turns.forEach(_cancel);
    _agent = Turn(const []);
  }

  void _cancel(Turn turn) => turn.cancelWaiting().forEach(showDecision);

  List<Turn> get _turns => [_agent, ..._outside.values];
}
