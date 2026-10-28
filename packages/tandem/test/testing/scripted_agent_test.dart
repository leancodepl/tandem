import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/testing.dart';

void main() {
  test(
    'repeating uses each raw request and keeps event ids distinct',
    () async {
      final seen = <Map<String, Object?>>[];
      final agent = ScriptedAgent.repeating((request) {
        seen.add(request);
        return [
          AgentStep.say('${request['prompt']}'),
          const AgentStep.callTool('read'),
        ];
      });
      final first = <String, Object?>{
        'threadId': 'thread',
        'runId': 'first',
        'prompt': 'One',
      };
      final second = <String, Object?>{
        'threadId': 'thread',
        'runId': 'second',
        'prompt': 'Two',
      };

      final firstEvents = await agent.run(first).toList();
      final secondEvents = await agent.run(second).toList();

      expect(seen.first, same(first));
      expect(seen.last, same(second));
      expect(agent.requests, [first, second]);
      expect(firstEvents, contains(containsPair('delta', 'One')));
      expect(secondEvents, contains(containsPair('delta', 'Two')));
      expect(firstEvents, contains(containsPair('messageId', 'msg-1')));
      expect(secondEvents, contains(containsPair('messageId', 'msg-2')));
      expect(firstEvents, contains(containsPair('toolCallId', 'call-1')));
      expect(secondEvents, contains(containsPair('toolCallId', 'call-2')));
      expect(firstEvents.last, {
        'type': 'RUN_FINISHED',
        'threadId': 'thread',
        'runId': 'first',
      });
      expect(secondEvents.last, {
        'type': 'RUN_FINISHED',
        'threadId': 'thread',
        'runId': 'second',
      });
    },
  );

  test('a finite script still fails after its last turn', () async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Done')],
    ]);

    final first = await agent.run({}).toList();
    final exhausted = await agent.run({}).toList();

    expect(first.last['type'], 'RUN_FINISHED');
    expect(exhausted.last, {
      'type': 'RUN_ERROR',
      'message': 'The script has no more turns.',
      'code': ScriptedErrorCode.scriptEnded,
    });
  });
}
