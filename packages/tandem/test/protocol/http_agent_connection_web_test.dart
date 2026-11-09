@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/agent_connection.dart';

void main() {
  test('over fetch, the requested run arrives and its terminal event '
      'closes the open connection', () async {
    final agent = spawnHybridUri('/test/support/sse_agent.dart');
    final messages = StreamIterator(agent.stream);
    addTearDown(messages.cancel);
    expect(await messages.moveNext(), isTrue);
    final endpoint = Uri.parse(messages.current as String);

    const ids = {'threadId': 'thread-current', 'runId': 'run-current'};
    await expectLater(
      HttpAgentConnection(endpoint).run({...ids, 'messages': []}),
      emitsInOrder([
        {...ids, 'type': 'RUN_STARTED'},
        {...ids, 'type': 'RUN_FINISHED'},
        emitsDone,
      ]),
    );

    expect(await messages.moveNext(), isTrue);
    expect(messages.current, 'closed');
  });
}
