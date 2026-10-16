/// A call of a listed method that did not run, because the agent called a
/// method that is not listed now or waits for approval, or sent arguments
/// that do not fit. [message] is written for the agent.
final class const ToolCallRefused(final String message) implements Exception {
  /// The call was refused for [message].
  this;

  @override
  String toString() => message;
}

/// The agent's endpoint answered with a status other than 200.
final class const AgentHttpException(final int statusCode, final String body)
    implements Exception {
  /// The endpoint answered with [statusCode] and [body].
  this;

  @override
  String toString() => 'AgentHttpException: $statusCode $body';
}

/// The agent's run ended with `RUN_ERROR`. The session reports it for the
/// logs only: the chat shows a notice and never the [message].
final class const AgentRunException(final String? code, final String? message)
    implements Exception {
  /// The run failed with [code], such as `EXECUTION_ERROR`, and [message].
  this;

  @override
  String toString() => 'AgentRunException: ${[?code, ?message].join(' ')}';
}
