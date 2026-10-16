// The run loop of a session: what each run sends, queued messages,
// automatic follow-ups and the loop guard, stop, errors and retry,
// tolerated events, diagnostics, and dispose.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'support.dart';

void main() {
  group('Runs', () {
    test('every run has the thread id, a new run id, the tools, the whole '
        'history and the extra context', () async {
      final search = RecordingTool(
        'search_catalog',
        params: {'query': const Param.string('What to look for')},
      );
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.say('Looking.'),
          AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
        ],
        (_) => const [AgentStep.say('Found nothing.')],
        (_) => const [AgentStep.say('Bye.')],
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: TandemOptions(
          threadId: 'thread-42',
          context: const {'locale': 'pl-PL', 'today': '2026-10-16'},
          onDiagnostic: (_) {},
        ),
      );

      await session.send('HDMI cables');
      await session.send('Bye');

      expect(agent.isExhausted, isTrue);
      expect(session.threadId, 'thread-42');
      final inputs = [for (final request in agent.requests) request.input];
      expect(inputs.map((input) => input.threadId).toSet(), {'thread-42'});
      expect(inputs.map((input) => input.runId).toSet(), hasLength(3));
      for (final input in inputs) {
        final body = input.toJson();
        expect(body['forwardedProps'], isEmpty);
        expect(body['tools'], [
          {
            'name': 'search_catalog',
            'description': 'The search_catalog tool.',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': 'What to look for'},
              },
              'required': ['query'],
            },
          },
        ]);
        expect(input.context.map((entry) => entry.toJson()), [
          {'description': 'locale', 'value': 'pl-PL'},
          {'description': 'today', 'value': '2026-10-16'},
        ]);
      }
      // The last run carries everything that happened before it.
      final history = inputs.last.messages;
      expect(history.map((message) => message.runtimeType), [
        WireUserMessage,
        WireAssistantMessage,
        WireAssistantMessage,
        WireToolMessage,
        WireAssistantMessage,
        WireUserMessage,
      ]);
      final call = (history[2] as WireAssistantMessage).toolCalls.single;
      expect(history[2].id, 'asst-${call.id}');
      expect(call.arguments, '{"query":"HDMI"}');
      final answer = history[3] as WireToolMessage;
      expect(answer.id, startsWith('tool-'));
      expect(answer.toolCallId, call.id);
      expect((history[4] as WireAssistantMessage).content, 'Found nothing.');
      await session.dispose();
    });

    test('sends tools: [] when the screen has no tools', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Hi.')],
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Hi');

      expect(agent.requests.single.input.toJson()['tools'], isEmpty);
      expect(session.threadId, matches(_uuid));
      expect(agent.requests.single.input.runId, matches(_uuid));
      await session.dispose();
    });

    test('a message sent during a run is queued and goes out with the next '
        'run, after the tool answers', () async {
      final search = RecordingTool('search_catalog', result: const ['HDMI-2M']);
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(typed.future),
          const AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
        ],
        (request) {
          expect(request.userText, 'Make it 50');
          expect(request.resultOf('search_catalog')?['status'], 'ok');
          final messages = request.input.messages;
          expect(messages[messages.length - 2], isA<WireToolMessage>());
          expect(messages.last, isA<WireUserMessage>());
          return const [AgentStep.say('50 it is.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      final first = session.send('40 HDMI cables');
      await pumpEventQueue();
      expect(session.view.isRunning, isTrue);
      var secondDone = false;
      final second = session.send('Make it 50').then((_) => secondDone = true);
      final queued = session.view.timeline.whereType<UserMessage>().last;
      expect(queued.text, 'Make it 50');
      expect(queued.isQueued, isTrue);
      expect(agent.requests, hasLength(1));

      typed.complete();
      await first;
      await second;

      expect(secondDone, isTrue);
      expect(agent.isExhausted, isTrue);
      expect(agent.requests, hasLength(2));
      expect(
        session.view.timeline.whereType<UserMessage>().map(
          (message) => message.isQueued,
        ),
        [false, false],
      );
      expect(session.view.isRunning, isFalse);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('the loop guard stops automatic follow-ups; the results wait for '
        'the next message', () async {
      final search = RecordingTool('search_catalog', result: const []);
      AgentTurn searchAgain(int run) => (request) {
        if (run > 1) {
          expect(request.userText, isNull);
        }
        return const [
          AgentStep.callTool('search_catalog', {'query': 'x'}),
        ];
      };
      final agent = ScriptedAgent([
        searchAgain(1),
        searchAgain(2),
        searchAgain(3),
        (request) {
          expect(request.userText, 'Stop searching');
          expect(request.resultOf('search_catalog')?['status'], 'ok');
          return const [AgentStep.say('Sorry.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: TandemOptions(maxAutoRuns: 2, onDiagnostic: (_) {}),
      );

      await session.send('Find something');

      // One run for the message, then two automatic follow-ups.
      expect(agent.requests, hasLength(3));
      expect(search.calls, hasLength(3));
      expect(session.view.isRunning, isFalse);
      expect(session.view.error?.kind, TandemErrorKind.loopGuard);
      expect(session.view.error?.message, contains('2 automatic follow-up'));

      await session.send('Stop searching');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('retry after the loop guard sends the held results', () async {
      final search = RecordingTool('search_catalog', result: const []);
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('search_catalog', {'query': 'x'}),
        ],
        (_) => const [
          AgentStep.callTool('search_catalog', {'query': 'y'}),
        ],
        (request) {
          expect(request.userText, isNull);
          expect(request.resultOf('search_catalog')?['status'], 'ok');
          return const [AgentStep.say('Done.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: TandemOptions(maxAutoRuns: 1, onDiagnostic: (_) {}),
      );

      await session.send('Find something');
      expect(session.view.error?.kind, TandemErrorKind.loopGuard);

      await session.view.error!.retry();

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('stop cancels the run; the calls it completed are answered as '
        'cancelled with the next run', () async {
      final search = RecordingTool('search_catalog');
      final place = RecordingTool('place_order', needsApproval: true);
      final never = Completer<void>();
      // Without mimicAdk the calls end at once; ag-ui-adk would end them
      // only after its final snapshot, so a stop drops them instead.
      final agent = ScriptedAgent(mimicAdk: false, [
        (_) => [
          const AgentStep.say('Searching.'),
          const AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
          const AgentStep.callTool('place_order'),
          const AgentStep.runAgentTool('find_customer', args: {'q': 'Acme'}),
          AgentStep.waitFor(never.future),
        ],
        (request) {
          expect(request.userText, 'Never mind');
          expect(request.resultOf('search_catalog'), {'status': 'cancelled'});
          expect(request.resultOf('place_order'), {'status': 'cancelled'});
          return const [AgentStep.say('OK.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool, place.tool],
        options: quiet,
      );

      unawaited(session.send('HDMI cables'));
      await pumpEventQueue();
      expect(session.view.isRunning, isTrue);

      await session.stop();

      expect(session.view.isRunning, isFalse);
      expect(session.view.error, isNull);
      expect(search.calls, isEmpty);
      expect(place.calls, isEmpty);
      expect(session.view.openApprovals, isEmpty);
      expect(
        session.view.timeline.whereType<ToolActivity>().map(
          (activity) => (activity.toolName, activity.status),
        ),
        [
          ('search_catalog', ToolActivityStatus.failed),
          ('find_customer', ToolActivityStatus.succeeded),
        ],
      );

      await session.send('Never mind');

      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });

    test('stop drops a call that was still streaming', () async {
      final search = RecordingTool('search_catalog');
      final connection = ManualConnection([
        (_) => _openEnded([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'call-1',
            'toolCallName': 'search_catalog',
          },
          {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'call-1', 'delta': '{"q'},
        ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r2'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r2'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      unawaited(session.send('HDMI cables'));
      await pumpEventQueue();
      await session.stop();
      await session.send('Again');

      final messages = connection.inputs.last.messages;
      expect(messages.whereType<WireUserMessage>(), hasLength(2));
      expect(messages.whereType<WireAssistantMessage>(), isEmpty);
      expect(messages.whereType<WireToolMessage>(), isEmpty);
      expect(search.calls, isEmpty);
      await session.dispose();
    });

    test('stop while tools run: the running tool finishes, the rest are '
        'cancelled, and nothing runs on its own', () async {
      final release = Completer<String>();
      final slow = Tool<OrderDraft>(
        'check_stock',
        'Slow.',
        run: (_) => release.future,
      );
      final search = RecordingTool('search_catalog');
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('check_stock'),
          AgentStep.callTool('search_catalog'),
        ],
        (request) {
          expect(request.userText, 'Go on');
          expect(request.resultOf('check_stock'), {
            'status': 'ok',
            'result': 'in stock',
          });
          expect(request.resultOf('search_catalog'), {'status': 'cancelled'});
          return const [AgentStep.say('OK.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [slow, search.tool],
        options: quiet,
      );

      unawaited(session.send('Check'));
      await pumpEventQueue();
      expect(session.view.isRunning, isTrue);
      final stopping = session.stop();
      release.complete('in stock');
      await stopping;
      await pumpEventQueue();

      expect(search.calls, isEmpty);
      expect(agent.requests, hasLength(1));
      expect(session.view.isRunning, isFalse);
      expect(
        session.view.timeline.whereType<ToolActivity>().map(
          (activity) => activity.status,
        ),
        [ToolActivityStatus.succeeded, ToolActivityStatus.failed],
      );

      await session.send('Go on');

      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });

    test('a tool waiting behind a running one stays cancelled after stop, '
        'also when the user acts before the running one returns', () async {
      for (final act in <String, Future<void> Function(TandemSession<Object?>)>{
        'send': (session) => session.send('No, keep the lines'),
        'approve': (session) => session.view.openApprovals.single.approve(),
      }.entries) {
        final release = Completer<String>();
        final slow = Tool<OrderDraft>(
          'check_stock',
          'Slow.',
          run: (_) => release.future,
        );
        final clear = RecordingTool('clear_lines');
        final place = RecordingTool('place_order', needsApproval: true);
        final agent = ScriptedAgent([
          (_) => const [
            AgentStep.callTool('place_order'),
            AgentStep.callTool('check_stock'),
            AgentStep.callTool('clear_lines'),
          ],
          (request) {
            expect(request.resultOf('check_stock'), {
              'status': 'ok',
              'result': 'in stock',
            });
            expect(request.resultOf('clear_lines'), {'status': 'cancelled'});
            return const [AgentStep.say('Kept the lines.')];
          },
        ]);
        final session = TandemSession(
          connection: agent,
          host: MemoryStateHost(OrderDraft.empty),
          codec: orderCodec,
          tools: [place.tool, slow, clear.tool],
          options: quiet,
        );

        unawaited(session.send('Check and clear'));
        await pumpEventQueue();
        expect(session.view.isRunning, isTrue, reason: act.key);
        unawaited(session.stop());
        final acting = act.value(session);
        release.complete('in stock');
        await acting;
        await pumpEventQueue();

        expect(clear.calls, isEmpty, reason: act.key);
        expect(agent.isExhausted, isTrue, reason: act.key);
        expect(session.view.error, isNull, reason: act.key);
        await session.dispose();
      }
    });

    test('stop sends the messages queued during the run at once, with the '
        'answers of the stopped run', () async {
      final search = RecordingTool('search_catalog');
      final never = Completer<void>();
      final agent = ScriptedAgent(mimicAdk: false, [
        (_) => [
          const AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
          AgentStep.waitFor(never.future),
        ],
        (request) {
          expect(request.resultOf('search_catalog'), {'status': 'cancelled'});
          expect(request.userText, 'Only 2 m cables');
          return const [AgentStep.say('Only 2 m then.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      unawaited(session.send('HDMI cables'));
      await pumpEventQueue();
      final queued = session.send('Only 2 m cables');
      expect(
        session.view.timeline.whereType<UserMessage>().last.isQueued,
        isTrue,
      );

      await session.stop();
      await queued;

      expect(agent.isExhausted, isTrue);
      expect(search.calls, isEmpty);
      expect(session.view.isRunning, isFalse);
      expect(
        session.view.timeline.whereType<UserMessage>().map(
          (message) => message.isQueued,
        ),
        [false, false],
      );
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('stop and dispose cancel the subscription to the run', () async {
      final cancelled = <String>[];
      Stream<WireEvent> endless(String runId) {
        late final StreamController<WireEvent> controller;
        controller = StreamController(
          onListen: () => controller.add(
            WireEvent.fromJson({
              'type': 'RUN_STARTED',
              'threadId': 't',
              'runId': runId,
            }),
          ),
          onCancel: () => cancelled.add(runId),
        );
        return controller.stream;
      }

      final connection = ManualConnection([
        (_) => endless('r1'),
        (_) => endless('r2'),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );

      unawaited(session.send('First'));
      await pumpEventQueue();
      await session.stop();
      expect(cancelled, ['r1']);

      unawaited(session.send('Second'));
      await pumpEventQueue();
      await session.dispose();
      expect(cancelled, ['r1', 'r2']);
    });

    test(
      'views come asynchronously after changes and close on dispose',
      () async {
        final agent = ScriptedAgent([
          (_) => const [AgentStep.say('Hello.')],
        ]);
        final session = TandemSession(
          connection: agent,
          host: MemoryStateHost(OrderDraft.empty),
          codec: orderCodec,
          options: quiet,
        );
        expect(session.view.timeline, isEmpty);
        expect(session.view.isRunning, isFalse);
        final views = <TandemView>[];
        final done = Completer<void>();
        session.views.listen(views.add, onDone: done.complete);

        final sending = session.send('Hi');
        expect(session.view.isRunning, isTrue);
        expect(views, isEmpty);
        await sending;

        expect(views, isNotEmpty);
        expect(views.any((view) => view.isRunning), isTrue);
        expect(
          views.any(
            (view) => view.timeline.any(
              (item) => item is AgentMessage && item.isStreaming,
            ),
          ),
          isTrue,
        );
        expect(views.last.isRunning, isFalse);
        expect((views.last.timeline.last as AgentMessage).text, 'Hello.');

        await session.dispose();
        await done.future;
      },
    );
  });

  group('Errors', () {
    test('RUN_ERROR without RUN_STARTED is an agent error; retry sends again, '
        'with the user edits it did not deliver', () async {
      final host = MemoryStateHost(OrderDraft.empty);
      final connection = ManualConnection([
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r1'},
        ]),
        (_) => events([
          {
            'type': 'RUN_ERROR',
            'message': 'No interrupt with that id',
            'code': 'UNKNOWN_INTERRUPT',
          },
        ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r3'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r3'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Hello');
      host.update((draft) => draft.copyWith(notes: 'Urgent'));
      await session.send('Again');

      final error = session.view.error!;
      expect(error.kind, TandemErrorKind.agent);
      expect(error.message, 'No interrupt with that id');
      expect(error.code, 'UNKNOWN_INTERRUPT');
      expect(session.view.isRunning, isFalse);
      expect(RunRequest(connection.inputs[1]).reportedUserEdits, [
        '/order/notes',
      ]);

      await error.retry();

      expect(connection.inputs, hasLength(3));
      expect(session.view.error, isNull);
      final retried = connection.inputs.last;
      expect(retried.messages.whereType<WireUserMessage>(), hasLength(2));
      expect(RunRequest(retried).reportedUserEdits, ['/order/notes']);
      expect(
        retried.messages.map((message) => message.id),
        connection.inputs[1].messages.map((message) => message.id),
      );
      await session.dispose();
    });

    test('a scripted RUN_ERROR shows its message and code until the next run '
        'starts', () async {
      final back = Completer<void>();
      final agent = ScriptedAgent([
        (_) => const [AgentStep.fail('Model overloaded', code: 'UNAVAILABLE')],
        (request) {
          expect(request.userText, isNull);
          return [AgentStep.waitFor(back.future), const AgentStep.say('Back.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Hello');
      final error = session.view.error!;
      expect(error.kind, TandemErrorKind.agent);
      expect(error.code, 'UNAVAILABLE');
      expect(error.message, 'Model overloaded');

      final retrying = error.retry();
      await pumpEventQueue();
      expect(session.view.isRunning, isTrue);
      expect(session.view.error, isNull);
      back.complete();
      await retrying;

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('a transport error is a connection error; calls of the failed run '
        'are answered as cancelled on retry', () async {
      final search = RecordingTool('search_catalog');
      final connection = ManualConnection([
        (_) => _failing([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'call-1',
            'toolCallName': 'search_catalog',
          },
          {'type': 'TOOL_CALL_END', 'toolCallId': 'call-1'},
        ], const SocketLikeException('Connection reset by peer')),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r2'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r2'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      await session.send('HDMI');

      final error = session.view.error!;
      expect(error.kind, TandemErrorKind.connection);
      expect(error.message, 'Connection reset by peer');
      expect(error.code, isNull);
      expect(search.calls, isEmpty);
      expect(
        session.view.timeline.whereType<ToolActivity>().single.status,
        ToolActivityStatus.failed,
      );

      await error.retry();

      final answer = connection.inputs.last.messages
          .whereType<WireToolMessage>()
          .single;
      expect(answer.toolCallId, 'call-1');
      expect(jsonDecode(answer.content), {'status': 'cancelled'});
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('a retry the backend answers with nothing after a run that had '
        'started says the answer is lost', () async {
      final connection = ManualConnection([
        (_) => _failing([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
        ], const SocketLikeException('Connection reset by peer')),
        // ag-ui-adk had processed the message: an empty pair.
        for (final runId in ['r2', 'r3'])
          (_) => events([
            {'type': 'RUN_STARTED', 'threadId': 't', 'runId': runId},
            {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': runId},
          ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r4'},
          {
            'type': 'TEXT_MESSAGE_START',
            'messageId': 'm1',
            'role': 'assistant',
          },
          {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'Hi.'},
          {'type': 'TEXT_MESSAGE_END', 'messageId': 'm1'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r4'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );

      await session.send('HDMI');
      await session.view.error!.retry();

      final lost = session.view.error!;
      expect(lost.kind, TandemErrorKind.connection);
      expect(lost.message, contains('answer is lost'));
      expect(lost.code, isNull);

      await lost.retry();
      expect(session.view.error?.message, contains('answer is lost'));

      await session.send('Hello again');
      expect(session.view.error, isNull);
      expect(connection.inputs, hasLength(4));
      await session.dispose();
    });

    test(
      'a stream that ends without RUN_FINISHED counts as finished',
      () async {
        final search = RecordingTool('search_catalog', result: 'found');
        final connection = ManualConnection([
          (_) => events([
            {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
            {
              'type': 'TEXT_MESSAGE_START',
              'messageId': 'm1',
              'role': 'assistant',
            },
            {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'Hm'},
            {
              'type': 'TOOL_CALL_START',
              'toolCallId': 'call-1',
              'toolCallName': 'search_catalog',
            },
            {'type': 'TOOL_CALL_END', 'toolCallId': 'call-1'},
          ]),
          (_) => events([
            {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r2'},
            {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r2'},
          ]),
        ]);
        final session = TandemSession(
          connection: connection,
          host: MemoryStateHost(OrderDraft.empty),
          codec: orderCodec,
          tools: [search.tool],
          options: quiet,
        );

        await session.send('HDMI');

        expect(session.view.error, isNull);
        expect(search.calls, hasLength(1));
        expect(connection.inputs, hasLength(2));
        final messages = connection.inputs.last.messages;
        expect((messages[1] as WireAssistantMessage).content, 'Hm');
        final answer = messages.whereType<WireToolMessage>().single;
        expect(jsonDecode(answer.content), {'status': 'ok', 'result': 'found'});
        expect(
          session.view.timeline.whereType<AgentMessage>().single.isStreaming,
          isFalse,
        );
        await session.dispose();
      },
    );

    test('a connection that throws when asked for a run is a connection '
        'error', () async {
      final connection = ManualConnection([
        (_) => throw const SocketLikeException('No route to host'),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Hello');

      expect(session.view.error?.kind, TandemErrorKind.connection);
      expect(session.view.error?.message, 'No route to host');
      await session.dispose();
    });
  });

  group('Tolerated events and diagnostics', () {
    test('unknown events and a patch that does not apply are ignored and '
        'reported; the run goes on', () async {
      final diagnostics = <TandemDiagnostic>[];
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.event({'type': 'STEP_STARTED', 'stepName': 'plan'}),
          AgentStep.event({'type': 'TEXT_MESSAGE_START'}),
          AgentStep.event({
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': 'nowhere',
            'delta': 'Lost',
          }),
          AgentStep.event({
            'type': 'STATE_DELTA',
            'delta': [
              {'op': 'replace', 'path': '/order/discount', 'value': 5},
            ],
          }),
          AgentStep.patchState([
            {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
          ]),
          AgentStep.say('Still here.'),
        ],
      ]);
      final host = MemoryStateHost(OrderDraft.empty);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: TandemOptions(onDiagnostic: diagnostics.add),
      );

      await session.send('Hello');

      expect(session.view.error, isNull);
      expect(host.state.notes, 'Urgent');
      expect(
        session.view.timeline.whereType<AgentMessage>().single.text,
        'Still here.',
      );
      expect(diagnostics.map((diagnostic) => diagnostic.message), [
        contains('"STEP_STARTED"'),
        contains('TEXT_MESSAGE_START'),
        contains('"nowhere"'),
        contains('STATE_DELTA'),
      ]);
      expect(diagnostics.first.detail, {
        'type': 'STEP_STARTED',
        'stepName': 'plan',
      });
      await session.dispose();
    });

    test('tool calls with a parentMessageId go into that message', () async {
      final search = RecordingTool('search_catalog');
      final agent = ScriptedAgent(mimicAdk: false, [
        (_) => const [
          AgentStep.say('Let me look.'),
          AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
        ],
        (request) {
          final assistant = request.input.messages
              .whereType<WireAssistantMessage>()
              .single;
          expect(assistant.content, 'Let me look.');
          expect(assistant.toolCalls.single.name, 'search_catalog');
          return const [AgentStep.say('Done.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      await session.send('HDMI');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('text and tool call chunks are expanded; an agent tool result '
        'becomes a tool message with its own id', () async {
      final search = RecordingTool('search_catalog', result: 1);
      final connection = ManualConnection([
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm1', 'delta': 'Hel'},
          {'type': 'TEXT_MESSAGE_CHUNK', 'delta': 'lo.'},
          {
            'type': 'TOOL_CALL_CHUNK',
            'toolCallId': 'call-1',
            'toolCallName': 'find_customer',
            'parentMessageId': 'm1',
            'delta': '{"q":',
          },
          {'type': 'TOOL_CALL_CHUNK', 'delta': '"Acme"}'},
          {
            'type': 'TOOL_CALL_RESULT',
            'messageId': 'result-1',
            'toolCallId': 'call-1',
            'content': '{"id":"C-17"}',
          },
          {
            'type': 'TOOL_CALL_CHUNK',
            'toolCallId': 'call-2',
            'toolCallName': 'search_catalog',
          },
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r1'},
        ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r2'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r2'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      await session.send('Acme');

      expect(search.calls.single.json, isEmpty);
      final messages = connection.inputs.last.messages;
      expect(messages.map((message) => message.toJson()), [
        {'id': messages.first.id, 'role': 'user', 'content': 'Acme'},
        {
          'id': 'm1',
          'role': 'assistant',
          'content': 'Hello.',
          'toolCalls': [
            {
              'id': 'call-1',
              'type': 'function',
              'function': {
                'name': 'find_customer',
                'arguments': '{"q":"Acme"}',
              },
            },
          ],
        },
        {
          'id': 'result-1',
          'role': 'tool',
          'content': '{"id":"C-17"}',
          'toolCallId': 'call-1',
        },
        {
          'id': 'asst-call-2',
          'role': 'assistant',
          'toolCalls': [
            {
              'id': 'call-2',
              'type': 'function',
              'function': {'name': 'search_catalog', 'arguments': '{}'},
            },
          ],
        },
        {
          'id': messages.last.id,
          'role': 'tool',
          'content': '{"status":"ok","result":1}',
          'toolCallId': 'call-2',
        },
      ]);
      expect(
        session.view.timeline.whereType<ToolActivity>().map(
          (activity) =>
              (activity.toolName, activity.status, activity.runsInApp),
        ),
        [
          ('find_customer', ToolActivityStatus.succeeded, false),
          ('search_catalog', ToolActivityStatus.succeeded, true),
        ],
      );
      await session.dispose();
    });

    test('an agent tool shows running until its result, also from a later '
        'run', () async {
      final connection = ManualConnection([
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'call-1',
            'toolCallName': 'export_order',
          },
          {'type': 'TOOL_CALL_END', 'toolCallId': 'call-1'},
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'call-2',
            'toolCallName': 'find_customer',
          },
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r1'},
        ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r2'},
          {
            'type': 'TOOL_CALL_RESULT',
            'messageId': 'result-1',
            'toolCallId': 'call-1',
            'content': '{"file":"order.pdf"}',
          },
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r2'},
        ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r3'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r3'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );
      List<ToolActivityStatus> statuses() => [
        for (final activity in session.view.timeline.whereType<ToolActivity>())
          activity.status,
      ];

      await session.send('Export it');
      // The second call never ended, so it can get no result.
      expect(statuses(), [
        ToolActivityStatus.running,
        ToolActivityStatus.failed,
      ]);

      await session.send('Done yet?');
      expect(statuses(), [
        ToolActivityStatus.succeeded,
        ToolActivityStatus.failed,
      ]);

      await session.send('Thanks');
      final messages = connection.inputs.last.messages;
      expect(messages.map((message) => message.id), [
        messages[0].id,
        'asst-call-1',
        messages[2].id,
        'result-1',
        messages[4].id,
      ]);
      await session.dispose();
    });

    test('MESSAGES_SNAPSHOT replaces the history, not the timeline', () async {
      final connection = ManualConnection([
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {
            'type': 'MESSAGES_SNAPSHOT',
            'messages': [
              {'id': 'u-0', 'role': 'user', 'content': 'Earlier'},
            ],
          },
          {
            'type': 'TEXT_MESSAGE_START',
            'messageId': 'm1',
            'role': 'assistant',
          },
          {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'Hi.'},
          {'type': 'TEXT_MESSAGE_END', 'messageId': 'm1'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r1'},
        ]),
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r2'},
          {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r2'},
        ]),
      ]);
      final session = TandemSession(
        connection: connection,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Hello');
      await session.send('Again');

      final ids = [
        for (final message in connection.inputs.last.messages) message.id,
      ];
      expect(ids, hasLength(3));
      expect(ids.take(2), ['u-0', 'm1']);
      expect(
        session.view.timeline.whereType<UserMessage>().map((m) => m.text),
        ['Hello', 'Again'],
      );
      await session.dispose();
    });
  });

  group('Dispose', () {
    test(
      'during a run: no host write afterwards, views close, send throws',
      () async {
        final typed = Completer<void>();
        final agent = ScriptedAgent([
          (_) => [
            const AgentStep.patchState([
              {'op': 'replace', 'path': '/order/notes', 'value': 'First'},
            ]),
            AgentStep.waitFor(typed.future),
            const AgentStep.patchState([
              {'op': 'replace', 'path': '/order/notes', 'value': 'Second'},
            ]),
          ],
        ]);
        final host = AsyncHost(OrderDraft.empty);
        final session = TandemSession(
          connection: agent,
          host: host,
          codec: orderCodec,
          options: quiet,
        );
        final viewsDone = Completer<void>();
        session.views.listen(null, onDone: viewsDone.complete);

        final sending = session.send('Notes');
        await pumpEventQueue();
        expect(host.writes, hasLength(1));

        final disposing = session.dispose();
        host.lock();
        typed.complete();
        await disposing;
        await sending;
        await pumpEventQueue();

        expect(host.state.notes, 'First');
        expect(identical(session.dispose(), disposing), isTrue);
        expect(() => session.send('Hello'), throwsStateError);
        await viewsDone.future;
        await session.stop();
      },
    );

    test('while an approved tool runs, completes the send and stop that wait '
        'for the session', () async {
      final release = Completer<String>();
      final place = Tool<OrderDraft>(
        'place_order',
        'Places it.',
        needsApproval: true,
        run: (_) => release.future,
      );
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('place_order')],
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [place],
        options: quiet,
      );
      await session.send('Place it');
      final approving = session.view.openApprovals.single.approve();
      await pumpEventQueue();
      expect(session.view.isRunning, isTrue);

      var isSent = false;
      var isStopped = false;
      unawaited(session.send('And a note').then((_) => isSent = true));
      unawaited(session.stop().then((_) => isStopped = true));
      await session.dispose();
      await pumpEventQueue();

      expect(isSent, isTrue);
      expect(isStopped, isTrue);
      release.complete('placed');
      await approving;
      expect(agent.requests, hasLength(1));
    });

    test('a tool that finishes after dispose writes nothing', () async {
      final release = Completer<String>();
      final slow = Tool<OrderDraft>(
        'slow_lookup',
        'Takes a while.',
        run: (_) => release.future,
      );
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('slow_lookup')],
      ]);
      final host = AsyncHost(OrderDraft.empty);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        tools: [slow],
        options: quiet,
      );

      unawaited(session.send('Look it up'));
      await pumpEventQueue();
      await session.dispose();
      host.lock();
      release.complete('done');
      await pumpEventQueue();

      expect(agent.requests, hasLength(1));
      expect(host.writes, isEmpty);
    });
  });
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// An exception whose text is what the error shows, like a socket error.
final class SocketLikeException implements Exception {
  const SocketLikeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [events], then a transport [error].
Stream<WireEvent> _failing(
  List<Map<String, Object?>> events,
  Exception error,
) async* {
  for (final event in events) {
    await Future<void>.value();
    yield WireEvent.fromJson(event);
  }
  await Future<void>.value();
  throw error;
}

/// [events], then nothing until the run is cancelled.
Stream<WireEvent> _openEnded(List<Map<String, Object?>> events) {
  final controller = StreamController<WireEvent>();
  for (final event in events) {
    controller.add(WireEvent.fromJson(event));
  }
  return controller.stream;
}
