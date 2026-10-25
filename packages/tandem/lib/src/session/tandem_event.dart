import 'package:tandem/src/errors.dart';
import 'package:tandem/src/session/caller.dart';

/// Something that happened in a session, for the app to react to, such as
/// with a snackbar. Approval requests are not events: they go to
/// `approvals:`.
sealed class const TandemEvent();

/// A call of a listed method that returned. Not sent for a call that was
/// refused or threw, nor once the session is disposed.
final class const AgentCall({
  /// The method's name in snake_case.
  required final String tool,

  /// The agent's arguments, decoded from JSON.
  required final Map<String, Object?> arguments,

  /// What the method returned, as JSON.
  required final Object? result,

  /// Who called the method.
  required final Caller caller,
}) extends TandemEvent;

/// The user or the backend stopped a run. Sent on every Stop that stops one,
/// and when the backend cancels one, whether it adds a notice or marks the
/// last message `stopped`.
final class const RunStopped() extends TandemEvent;

/// A run ended with an error, or the app's agent list threw. The error goes
/// to `FlutterError.reportError`. After a run Tandem cannot follow, such as
/// one that ends with an interrupt, the next message goes to a new thread,
/// without the earlier history.
final class const RunFailed({
  /// The `code` of the backend's `RUN_ERROR`, or one of Tandem's own. Null
  /// when the error has none, such as when the agent list threw.
  final RunErrorCode? code,
}) extends TandemEvent;

/// A run broke off. The next message goes to a new thread, without the
/// earlier history.
final class const ConnectionLost() extends TandemEvent;
