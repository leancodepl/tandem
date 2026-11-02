import 'package:tandem/tandem.dart';
import 'package:waypoint/l10n/app_localizations.dart';

enum AgentFailure() {
  unreachable,
  runFailed;

  static AgentFailure? of(ChatNoticeKind kind) => switch (kind) {
    .connectionLost => .unreachable,
    .runFailed => .runFailed,
    .stopped || .startedOver => null,
  };
}

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
  String agentFailure(AgentFailure failure) => switch (failure) {
    .unreachable => agentUnreachable,
    .runFailed => agentRunFailed,
  };
}
