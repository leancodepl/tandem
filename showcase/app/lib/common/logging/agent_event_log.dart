import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';

extension AgentEventLog on Logger {
  /// Logs what the agent did, without its arguments and results, which hold
  /// what the traveller wrote. A [RunFailed] is left out: Tandem reports its
  /// error, and the logging setup logs that.
  void agentEvent(TandemEvent event) {
    switch (event) {
      case AgentCall(:final tool, :final caller):
        info('${caller.name} called $tool');
      case RunStopped():
        info('Agent run stopped');
      case ConnectionLost():
        warning('Agent connection lost');
      case RunFailed():
        break;
    }
  }
}
