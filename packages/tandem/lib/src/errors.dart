/// A call of a listed method that did not run, because the agent called a
/// method that is not listed now or waits for approval, or sent arguments
/// that do not fit. [message] is written for the agent.
final class const ToolCallRefused(final String message) implements Exception {
  @override
  String toString() => message;
}

/// The agent's endpoint answered with a status other than 200.
final class const AgentHttpException(final int statusCode, final String body)
    implements Exception {
  @override
  String toString() => 'AgentHttpException: $statusCode $body';
}

/// The agent's run ended with `RUN_ERROR`. The session reports it for the
/// logs only: the chat shows a notice and never the [message], which can be
/// 2 KB of the model provider's JSON.
final class const AgentRunException(final String? code, final String? message)
    implements Exception {
  @override
  String toString() => 'AgentRunException: ${[?code, ?message].join(' ')}';
}
