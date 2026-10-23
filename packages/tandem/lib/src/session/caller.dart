import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/tool_call.dart';

/// Who calls a listed method from outside the in-app agent's run. The answer
/// goes only to the caller, never to the in-app agent's history.
enum Caller() {
  /// A coding agent through `TandemBridge`.
  codingAgent,

  /// A coding agent through `TandemBridge.enable(autoApprove: true)`.
  automation;

  /// Whether every call runs at once, without asking the user.
  bool get approvedInAdvance => this == automation;

  /// Why [tool] cannot wait for the user on a screen with `approvals: .none()`.
  String cannotAsk(String tool) =>
      "$tool needs the user's approval, but this screen has approvals: "
      '.none(). TandemBridge.enable(autoApprove: true) approves the calls of a '
      'coding agent.';

  /// Why [tool] cannot wait while [waiting], an earlier call, still does.
  String busy(String waiting, String tool) =>
      '$waiting waits for the user or still runs. Repeat that call to wait for '
      'its answer before you call $tool.';
}

/// What a caller from outside the in-app agent's run sees of a session.
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class OutsideCalls {
  /// Calls [tool] with [arguments]. A call that needs approval waits for the
  /// user as an `ApprovalRequest`, which shows once the session is idle,
  /// after the in-app agent's. One waits per caller: the same call waits for
  /// the same answer, and another is refused. Throws a `StateError` when the
  /// agent list does not fit the generated code.
  Future<ToolAnswer> call(
    Caller caller,
    String tool,
    Map<String, Object?> arguments,
  );

  /// The last call of [caller] that asked the user, null before the first.
  ToolCall? lastAsked(Caller caller);
}
