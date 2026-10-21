import 'package:tandem/src/chat/chat_item.dart';

/// Thrown by `approve` and `reject` for a request that no longer waits for
/// the user: one that was invalidated, cancelled or decided the other way.
/// [request] has its current status.
final class const ApprovalNotPending(final ApprovalRequest request)
    implements Exception {
  @override
  String toString() =>
      'ApprovalNotPending: ${request.tool} is ${request.status.name}.';
}

/// A call of a listed method that did not run, because the agent called a
/// method that is not listed now or waits for approval, or sent arguments
/// that do not fit. A method may throw it too, to refuse a call before it
/// changes any state. [message] goes to the agent and must be safe to share.
final class const ToolCallRefused(final String message) implements Exception {
  @override
  String toString() => message;
}

/// The agent's endpoint answered with a status other than 200.
final class const AgentHttpException(
  /// The HTTP status the endpoint answered with.
  final int statusCode,

  /// The response body as text, such as the server's error message.
  final String body,
) implements Exception {
  @override
  String toString() => 'AgentHttpException: $statusCode $body';
}

/// The agent's run ended with `RUN_ERROR`. The session reports it for the
/// logs only: the chat shows a notice and never the [message], which can be
/// 2 KB of the model provider's JSON.
final class const AgentRunException(
  final RunErrorCode? code,
  final String? message,
) implements Exception {
  @override
  String toString() => 'AgentRunException: ${[?code, ?message].join(' ')}';
}

/// The code of a failed run. A backend can send any string. The session's
/// own code is here; a connection that sends its own codes has a type for
/// them, such as `ScriptedErrorCode`.
extension type const RunErrorCode(String value) implements String {
  /// The run ended with an AG-UI outcome Tandem cannot follow, such as an
  /// interrupt.
  static const unsupportedOutcome = RunErrorCode('UNSUPPORTED_OUTCOME');
}
