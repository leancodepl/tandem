import 'package:tandem/tandem.dart';
import 'package:waypoint/l10n/app_localizations.dart';

/// Why the agent did not answer, as a screen tells the traveller next to
/// its Retry.
sealed class const AgentFailure() {
  /// The failure that a notice of [kind] reports, or null for a notice that
  /// reports none.
  static AgentFailure? of(ChatNoticeKind kind) => switch (kind) {
    .connectionLost => const AgentUnreachable(),
    .runFailed => const AgentRunFailed(),
    .stopped || .startedOver => null,
  };
}

/// The run broke off. The agent is Waypoint's only peer on the network, so
/// whether the device is online would not tell why.
final class const AgentUnreachable() extends AgentFailure;

/// The agent's run ended with an error.
final class const AgentRunFailed() extends AgentFailure;

extension SessionFailure on TandemSession {
  /// The failure of the last run, while nothing happened after it.
  AgentFailure? get failure => switch ((status, items.lastOrNull)) {
    (Idle(), ChatNotice(:final kind)) => AgentFailure.of(kind),
    _ => null,
  };

  /// Repeats the request of the run that failed. A failed run leaves the
  /// app's notes new, so waking the agent again repeats a request of the app.
  void retry() {
    switch (items.whereType<UserMessage>().lastOrNull) {
      case UserMessage(fromApp: true):
        wake();
      case UserMessage(:final text):
        send(text);
      case null:
        break;
    }
  }
}

extension AgentFailureText on AppLocalizations {
  /// What the screen tells the traveller about [failure].
  String agentFailure(AgentFailure failure) => switch (failure) {
    AgentUnreachable() => agentUnreachable,
    AgentRunFailed() => agentRunFailed,
  };
}
