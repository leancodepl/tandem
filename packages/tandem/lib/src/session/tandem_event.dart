/// Something that happened in a session, for the app to react to, such as
/// with a snackbar. Approval requests are not events: they go to
/// `approvals:`.
sealed class const TandemEvent();

/// A call of a listed method that returned. Not sent for a call that was
/// refused or threw, nor once the session is disposed.
final class const AgentCall({
  /// The method's name in snake_case.
  required final String tool,
  required final Map<String, Object?> arguments,

  /// What the method returned, as JSON.
  required final Object? result,
}) extends TandemEvent;

/// The user stopped a run. Sent on every Stop that stops one, whether it
/// adds a notice or marks the last message `stopped`.
final class const RunStopped() extends TandemEvent;

/// A run ended with an error, or the app's agent list threw. The error goes
/// to `FlutterError.reportError`.
final class const RunFailed() extends TandemEvent;

/// A run broke off. The next message goes to a new thread, without the
/// earlier history.
final class const ConnectionLost() extends TandemEvent;
