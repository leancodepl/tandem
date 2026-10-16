import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'support.dart';

/// The description Tandem gives the context entry with the user's edits.
const _userEdits =
    'Fields of the shared state the user changed by hand since the previous '
    'run, as JSON Pointers into the state';

const _searchCall = WireAssistantMessage(
  'asst-call-1',
  toolCalls: [
    WireToolCall(id: 'call-1', name: 'search_catalog', arguments: '{}'),
  ],
);

void main() {
  group('RunRequest.userText', () {
    test('is the user message new in this run', () {
      final request = RunRequest(
        runInput(
          'run-2',
          messages: const [
            firstUserMessage,
            WireAssistantMessage('msg-1', content: 'Which monitor?'),
            WireUserMessage('user-2', 'The Dell'),
          ],
        ),
        previous: runInput('run-1'),
      );

      expect(request.userText, 'The Dell');
    });

    test('is null in a run without a new user message', () {
      final request = RunRequest(
        runInput('run-2', messages: const [firstUserMessage, _searchCall]),
        previous: runInput('run-1'),
      );

      expect(request.userText, isNull);
    });

    test('is the last of several new user messages', () {
      final request = RunRequest(
        runInput(
          'run-1',
          messages: const [
            firstUserMessage,
            WireUserMessage('user-2', 'And 12 monitors'),
          ],
        ),
      );

      expect(request.userText, 'And 12 monitors');
    });
  });

  group('RunRequest.state', () {
    test('is the state the app sent', () {
      final request = RunRequest(runInput('run-1', state: const {'count': 3}));

      expect(request.state, {'count': 3});
    });

    test('decodes with a codec', () {
      final request = RunRequest(runInput('run-1', state: const {'count': 3}));

      expect(request.stateAs(const _CountCodec(), 0), 3);
    });
  });

  group('RunRequest.resultOf', () {
    test('decodes the latest answer new in this run', () {
      final request = RunRequest(
        runInput(
          'run-3',
          messages: const [
            firstUserMessage,
            _searchCall,
            WireToolMessage(
              'tool-1',
              toolCallId: 'call-1',
              content: '{"status":"ok","result":[]}',
            ),
            WireAssistantMessage(
              'asst-call-2',
              toolCalls: [
                WireToolCall(
                  id: 'call-2',
                  name: 'search_catalog',
                  arguments: '{}',
                ),
              ],
            ),
            WireToolMessage(
              'tool-2',
              toolCallId: 'call-2',
              content: '{"status":"error","error":"Timeout"}',
            ),
          ],
        ),
        previous: runInput('run-2'),
      );

      expect(request.resultOf('search_catalog'), {
        'status': 'error',
        'error': 'Timeout',
      });
      expect(request.resultOf('place_order'), isNull);
    });

    test('is null when the answer was sent in an earlier run', () {
      const messages = [
        firstUserMessage,
        _searchCall,
        WireToolMessage('tool-1', toolCallId: 'call-1', content: '{}'),
      ];
      final request = RunRequest(
        runInput(
          'run-3',
          messages: const [...messages, WireUserMessage('user-2', 'Thanks')],
        ),
        previous: runInput('run-2', messages: messages),
      );

      expect(request.resultOf('search_catalog'), isNull);
    });

    test('rejects an answer that is not a JSON object', () {
      final request = RunRequest(
        runInput(
          'run-2',
          messages: const [
            firstUserMessage,
            _searchCall,
            WireToolMessage('tool-1', toolCallId: 'call-1', content: 'done'),
          ],
        ),
      );

      expect(
        () => request.resultOf('search_catalog'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'The answer to the search_catalog call call-1 is not JSON.',
          ),
        ),
      );
    });
  });

  group('RunRequest.reportedUserEdits', () {
    test('are the JSON Pointers the session reported', () {
      final request = RunRequest(
        runInput(
          'run-2',
          context: const [
            WireContext(description: 'locale', value: 'pl-PL'),
            WireContext(
              description: _userEdits,
              value: '["/order/lines/1/quantity","/order/notes"]',
            ),
          ],
        ),
      );

      expect(request.reportedUserEdits, [
        '/order/lines/1/quantity',
        '/order/notes',
      ]);
    });

    test('are empty when the session reported none', () {
      final request = RunRequest(runInput('run-1'));

      expect(request.reportedUserEdits, isEmpty);
    });

    test('reject a value that is not a list of pointers', () {
      final request = RunRequest(
        runInput(
          'run-2',
          context: const [
            WireContext(description: _userEdits, value: '/order/notes'),
          ],
        ),
      );

      expect(() => request.reportedUserEdits, throwsA(isA<FormatException>()));
    });
  });

  test('a scripted agent hands every turn the request with the previous '
      'run', () async {
    final agent = ScriptedAgent([
      (request) {
        expect(request.userText, firstUserMessage.content);
        return const [AgentStep.callTool('search_catalog')];
      },
      (request) {
        expect(request.userText, isNull);
        expect(request.resultOf('search_catalog'), {
          'status': 'ok',
          'result': null,
        });
        return const [];
      },
    ]);
    final tools = [appTool('search_catalog')];

    final first = await play(agent, runInput('run-1', tools: tools));
    final second = await play(
      agent,
      runInput(
        'run-2',
        messages: [
          ...historyAfter([firstUserMessage], first),
          answer(callIdOf(first, 'search_catalog')),
        ],
        tools: tools,
      ),
    );

    expect(second.whereType<RunError>(), isEmpty);
    expect(agent.isExhausted, isTrue);
  });
}

/// A codec for an `int` stored under `count`.
final class _CountCodec extends StateCodec<int> {
  const _CountCodec();

  @override
  Set<String> get keys => const {'count'};

  @override
  Map<String, Object?> encode(int state) => {'count': state};

  @override
  int decode(int current, Map<String, Object?> document) =>
      switch (document['count']) {
        final int count => count,
        _ => current,
      };
}
