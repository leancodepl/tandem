import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';

/// The turns whose calls may wait for the user: the in-app agent's turn,
/// then one turn for each other caller, in the order they asked. One request
/// shows at a time, the in-app agent's first.
final class WaitingTurns() {
  /// The calls of the in-app agent's last run, until their answers go out.
  Turn agent = Turn(const []);

  final _others = <Caller, Turn>{};

  /// The request that waits for the user now.
  ApprovalRequest? get shown =>
      _turns.map((turn) => turn.awaited).nonNulls.firstOrNull;

  /// Whether a call waits for the user, shown or not.
  bool get waitsForUser => _turns.any((turn) => turn.waitsForUser);

  /// The last call of [caller] that asked the user, null before the first.
  ToolCall? lastAsked(Caller caller) => _others[caller]?.calls.singleOrNull;

  /// [call] of [caller] waits for the user after the turns that wait
  /// already, for what the agent sees as [seen].
  void ask(Caller caller, ToolCall call, SeesSnapshot seen) {
    _others.remove(caller);
    _others[caller] = Turn([call])..ask(seen);
  }

  /// Shows the next call that waits, unless a request shows already, and
  /// returns its request.
  ApprovalRequest? showNext() {
    if (shown != null) {
      return null;
    }
    for (final turn in _turns) {
      if (turn.next() case final request?) {
        return request;
      }
    }
    return null;
  }

  /// The turn that [request] belongs to.
  Turn turnOf(ApprovalRequest request) => _others.values.firstWhere(
    (turn) => turn.calls.any((call) => call.id == request.toolCallId),
    orElse: () => agent,
  );

  /// Invalidates the waiting calls of every turn that saw other than [seen],
  /// and returns them.
  List<ToolCall> invalidateUnlike(SeesSnapshot seen) => [
    for (final turn in _turns)
      if (turn.waitsForUser && turn.seen != seen) ...turn.invalidateWaiting(),
  ];

  /// Cancels the request of another caller that shows, because the user
  /// wrote instead of deciding, and returns its call.
  List<ToolCall> cancelShownOfOthers() => [
    for (final turn in _others.values)
      if (turn.awaited != null) ...turn.cancelWaiting(),
  ];

  /// Cancels every call that waits and returns them.
  List<ToolCall> cancelAll() => [
    for (final turn in _turns) ...turn.cancelWaiting(),
  ];

  List<Turn> get _turns => [agent, ..._others.values];
}
