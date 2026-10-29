import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';

void main() {
  test("the agent's calls are logged without what they carry", () {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    final log = Logger('Trip');

    const <TandemEvent>[
      AgentCall(
        tool: 'message_host',
        arguments: {'text': 'I land at 08:40.'},
        result: 'Sent.',
        caller: .view,
      ),
      RunStopped(),
      ConnectionLost(),
      RunFailed(),
    ].forEach(log.agentEvent);

    expect(records.map((record) => (record.level, record.message)), [
      (Level.INFO, 'view called message_host'),
      (Level.INFO, 'Agent run stopped'),
      (Level.WARNING, 'Agent connection lost'),
    ]);
  });
}
