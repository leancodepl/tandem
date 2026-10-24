import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/chat/chat_item.dart';
import 'package:tandem/src/report.dart';
import 'package:tandem/src/session/caller.dart';
import 'package:tandem/src/session/run.dart';
import 'package:tandem/src/session/run_method.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/session_status.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';
import 'package:tandem/src/session/turn.dart';
import 'package:tandem/src/session/waiting_requests.dart';
import 'package:uuid/uuid.dart';

/// The calls of one screen's listed methods, from every caller: the in-app
/// agent's turn, whose answers go back with its next run, and the calls of
/// outside callers, whose answers go to them. A call of the attached
/// view's tool in the turn goes to the view. A call that needs
/// approval waits for the user as an [ApprovalRequest], one at a time, and
/// is invalidated once what the agent sees differs from what it saw.
final class CallPipeline({
  required final AgentSurface _surface,

  /// The session's chat, where the requests show.
  required List<ChatItem> items,
  required final Run? Function() _openRun,

  /// Goes on once a request was decided and, when approved, its method
  /// returned.
  required final void Function({required bool agentTurn}) _decided,
  required final void Function() _notify,
  required final void Function(TandemEvent event) _emit,

  /// Gives the in-app agent a note with its next run.
  required final void Function(String note) _tellAgent,
  required final Future<void> Function(ApprovalRequest request)?
  _onApprovalRequest,
  required final bool Function() _asksForApproval,
}) implements OutsideCalls {
  final _requests = WaitingRequests(items);
  Calling? _calling;
  var _disposed = false;

  /// The listed method that runs now, for the in-app agent's turn or for a
  /// request the user approved.
  Calling? get calling => _calling;

  /// What the calls do while no run is open.
  SessionStatus get status => switch ((_calling, _requests.shown)) {
    (final calling?, _) => calling,
    (_, final request?) => AwaitingApproval(request),
    _ => const Idle(),
  };

  /// Whether every call of the in-app agent's turn has an answer, so the
  /// answers can go to it.
  bool get answersDue => _requests.agent.answered;

  /// Takes the calls of [run] as the in-app agent's turn.
  void takeTurn(Run run) => _requests.openAgentTurn([...run.calls.values]);

  /// Runs the calls of the turn of [run] that need no approval, in order,
  /// then asks the user about the rest. Stops once [run] is stopped or no
  /// longer open. Throws when the agent list throws.
  Future<void> answerTurn(Run run) async {
    final turn = _requests.agent;
    invalidateIfSeesChanged();
    for (final call in turn.calls) {
      if (!_isOpen(run)) {
        return;
      }
      await _answer(run, call);
    }
    if (_isOpen(run)) {
      _askAboutTurn(turn, seesChanged: run.seesChanged);
    }
  }

  /// Cancels what of the in-app agent's turn waits and returns the turn, for
  /// its answers to go with the next run.
  Turn closeTurn() => _requests.closeAgentTurn();

  /// Forgets the in-app agent's turn, for a thread that starts over.
  void dropTurn() => _requests.openAgentTurn(const []);

  /// Shows the next request that waits, the in-app agent's first, and gives
  /// it to `approvals:`.
  void showNext() {
    final request = _requests.showNext();
    _notify();
    if (request != null) {
      unawaited(_giveToApp(request));
    }
  }

  /// Invalidates for good every request whose turn saw other than what the
  /// agent sees now, then shows the next one when the session is idle. Notes
  /// a change for the open run.
  void invalidateIfSeesChanged() {
    final run = _openRun();
    if (run == null && !_requests.waitsForUser) {
      return;
    }
    final seen = _seesNow;
    if (run != null) {
      run.seesChanged = run.seesChanged || seen != SeesSnapshot.of(run.listing);
    }
    if (!_requests.invalidate(seen)) {
      return;
    }
    // A request that no longer shows uncovers the next one.
    if (_isIdle) {
      showNext();
    } else {
      _notify();
    }
  }

  void approve(ApprovalRequest request) {
    // `changes` may not report every value the agent sees.
    invalidateIfSeesChanged();
    final turn = _requests.turnOf(request);
    if (turn.approve(_requests.latest(request)) case final call?) {
      _requests.showDecision(call);
      unawaited(_runApproved(call, turn));
    }
  }

  void reject(ApprovalRequest request) {
    final turn = _requests.turnOf(request);
    if (turn.reject(_requests.latest(request)) case final call?) {
      _requests.showDecision(call);
      _decided(agentTurn: _requests.isAgentTurn(turn));
    }
  }

  bool isPending(ApprovalRequest request) =>
      _requests.turnOf(request).isPending(request);

  /// Cancels the request of an outside caller that shows, because the user
  /// wrote instead of deciding.
  void cancelShownOutside() => _requests.cancelShownOutside();

  /// Cancels every request that waits and forgets the in-app agent's turn.
  void cancelAll() => _requests.cancelAll();

  /// Cancels the requests that wait. Nothing emits, notifies or goes on
  /// after it.
  void dispose() {
    _disposed = true;
    _requests.cancelAll();
  }

  @override
  Future<ToolAnswer> call(
    Caller caller,
    String tool,
    Map<String, Object?> arguments,
  ) async {
    final argumentsJson = jsonEncode(arguments);
    final answer = await _callFrom(caller, tool, argumentsJson);
    if (answer.ran && !_disposed) {
      if (caller.toldAgent(tool, argumentsJson, answer) case final note?) {
        _tellAgent(note);
      }
    }
    return answer;
  }

  @override
  ToolCall? lastAsked(Caller caller) => _requests.lastAsked(caller);

  Future<ToolAnswer> _callFrom(
    Caller caller,
    String tool,
    String argumentsJson,
  ) {
    final listing = AgentListing.of(_surface);
    if (caller.approvedInAdvance) {
      return _callMethod(listing, tool, argumentsJson, approved: true);
    }
    if (listing.needsApproval(tool)) {
      final call = ToolCall(const Uuid().v4(), tool, listing.description(tool))
        ..arguments = argumentsJson;
      return _waitForUser(caller, call);
    }
    return _callMethod(listing, tool, argumentsJson, approved: false);
  }

  Future<ToolAnswer> _waitForUser(Caller caller, ToolCall call) async {
    if (lastAsked(caller) case final waiting? when waiting.answer == null) {
      if (waiting.tool == call.tool && waiting.arguments == call.arguments) {
        return await waiting.answered;
      }
      return .refused(caller.busy(waiting.tool, call.tool));
    }
    if (!_asksForApproval()) {
      return .refused(caller.cannotAsk(call.tool));
    }
    _requests.ask(caller, call, _seesNow);
    if (_isIdle) {
      showNext();
    }
    return await call.answered;
  }

  Future<void> _answer(Run run, ToolCall call) async {
    final arguments = call.objectArguments;
    if (arguments == null) {
      call.answer = .refused('The arguments must be a JSON object.');
      return;
    }
    if (run.viewOf(call.tool) case final view?) {
      call.answer = view.show(arguments);
      return;
    }
    if (run.listing.needsApproval(call.tool)) {
      return;
    }
    _calling = Calling(call.tool, approved: false);
    _notify();
    // A listener may stop the run.
    if (run.stopped) {
      _calling = null;
      return;
    }
    call.answer = await _callMethod(
      run.listing,
      call.tool,
      call.argumentsJson,
      approved: false,
    );
    _calling = null;
    invalidateIfSeesChanged();
  }

  void _askAboutTurn(Turn turn, {required bool seesChanged}) {
    if (!_asksForApproval()) {
      _refuseApprovals(turn);
    } else if (seesChanged) {
      // The agent asked about what it has not seen.
      turn.invalidateWaiting();
    } else {
      turn.ask(_seesNow);
    }
  }

  void _refuseApprovals(Turn turn) {
    final refused = turn.refuseWaiting(
      'The user cannot approve calls on this screen.',
    );
    for (final call in refused) {
      if (kDebugMode) {
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

  // Runs as Calling, so a message sent meanwhile waits for it.
  Future<void> _runApproved(ToolCall call, Turn turn) async {
    _calling = Calling(call.tool, approved: true);
    _notify();
    call.answer = await _callMethod(
      AgentListing.of(_surface),
      call.tool,
      call.argumentsJson,
      approved: true,
    );
    if (_disposed) {
      return;
    }
    invalidateIfSeesChanged();
    _calling = null;
    _decided(agentTurn: _requests.isAgentTurn(turn));
  }

  Future<ToolAnswer> _callMethod(
    AgentListing listing,
    String tool,
    String argumentsJson, {
    required bool approved,
  }) async {
    final (:answer, :returned) = await runMethod(
      listing,
      tool,
      argumentsJson,
      approved: approved,
      report: report,
    );
    if (returned case final agentCall? when !_disposed) {
      _emit(agentCall);
    }
    return answer;
  }

  Future<void> _giveToApp(ApprovalRequest request) async {
    try {
      await _onApprovalRequest?.call(request);
    } catch (err, st) {
      report(err, st);
    }
  }

  bool _isOpen(Run run) => !run.stopped && identical(_openRun(), run);

  bool get _isIdle => _openRun() == null && status is Idle;

  SeesSnapshot get _seesNow => .read(_surface, report: report);
}
