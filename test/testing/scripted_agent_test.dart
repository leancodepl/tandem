import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/testing.dart';

import '../protocol/fixtures/ag_ui_adk.dart';
import 'support.dart';

void main() {
  group('ScriptedAgent', () {
    test('plays one turn per run and keeps every request', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Hello.')],
        (_) => const [AgentStep.say('Bye.')],
      ]);

      final first = await play(agent, runInput('run-1'));
      expect(agent.isExhausted, isFalse);
      final second = await play(
        agent,
        runInput('run-2', messages: historyAfter([firstUserMessage], first)),
      );

      expect(agent.isExhausted, isTrue);
      expect(agent.requests.map((request) => request.input.runId), [
        'run-1',
        'run-2',
      ]);
      expect(_text(first), 'Hello.');
      expect(_text(second), 'Bye.');
    });

    test('does nothing until the run is listened to', () async {
      var turns = 0;
      final agent = ScriptedAgent([
        (_) {
          turns++;
          return const [];
        },
      ]);

      final events = agent.run(runInput('run-1'));
      await pumpEventQueue();

      expect(agent.requests, isEmpty);
      expect(turns, 0);
      await events.toList();
      expect(agent.requests, hasLength(1));
      expect(turns, 1);
    });

    testWidgets('sends events in microtasks, so one pump drains a run', (
      tester,
    ) async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.say('Looking for HDMI cables.'),
          AgentStep.callTool('search_catalog', {'query': 'HDMI 2m'}),
        ],
      ]);
      final events = <WireEvent>[];

      agent
          .run(runInput('run-1', tools: [appTool('search_catalog')]))
          .listen(events.add);
      expect(events, isEmpty);
      await tester.pump();

      expect(events.first, isA<RunStarted>());
      expect(events.last, isA<RunFinished>());
    });

    test('says a text as one message in pieces', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Found two monitors for you.')],
      ]);

      final events = await play(agent, runInput('run-1'));

      expect(typesOf(events), [
        'RUN_STARTED',
        'TEXT_MESSAGE_START',
        'TEXT_MESSAGE_CONTENT',
        'TEXT_MESSAGE_CONTENT',
        'TEXT_MESSAGE_CONTENT',
        'TEXT_MESSAGE_END',
        'STATE_SNAPSHOT',
        'RUN_FINISHED',
      ]);
      final ids = {
        for (final event in events.whereType<TextStart>()) event.messageId,
        for (final event in events.whereType<TextContent>()) event.messageId,
        for (final event in events.whereType<TextEnd>()) event.messageId,
      };
      expect(ids, hasLength(1));
      expect(_text(events), 'Found two monitors for you.');
    });

    test('says an empty text without content events', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('')],
      ]);

      final events = await play(agent, runInput('run-1'));

      expect(typesOf(events), [
        'RUN_STARTED',
        'TEXT_MESSAGE_START',
        'TEXT_MESSAGE_END',
        'STATE_SNAPSHOT',
        'RUN_FINISHED',
      ]);
    });

    test('ends a run with RUN_ERROR at a failure', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
          AgentStep.fail('The model is overloaded.', code: 'UNAVAILABLE'),
          AgentStep.say('Never said.'),
        ],
      ]);

      final events = await play(
        agent,
        runInput('run-1', tools: [appTool('search_catalog')]),
      );

      // The call's END is still held back, as ag-ui-adk holds it, so the
      // app never sees the call complete.
      expect(typesOf(events), [
        'RUN_STARTED',
        'TOOL_CALL_START',
        'TOOL_CALL_ARGS',
        'RUN_ERROR',
      ]);
      final error = events.last as RunError;
      expect(error.message, 'The model is overloaded.');
      expect(error.code, 'UNAVAILABLE');
    });

    test('sends an event exactly as given, unknown types too', () async {
      const custom = {
        'type': 'SUBAGENT_STARTED',
        'subagentRunId': 'sub-1',
        'nested': {
          'list': [1, 2],
        },
      };
      final agent = ScriptedAgent([
        (_) => const [AgentStep.event(custom)],
      ]);

      final events = await play(agent, runInput('run-1'));

      expect(events[1], isA<UnknownEvent>());
      expect(events[1].json, custom);
      expect(events.last, isA<RunFinished>());
    });

    test(
      'ends the run at a RUN_ERROR or RUN_FINISHED sent as an event',
      () async {
        final agent = ScriptedAgent([
          (_) => const [
            AgentStep.event({'type': 'RUN_ERROR', 'message': 'Gone'}),
            AgentStep.say('Never said.'),
          ],
          (_) => const [
            AgentStep.event({
              'type': 'RUN_FINISHED',
              'threadId': threadId,
              'runId': 'run-2',
            }),
            AgentStep.say('Never said.'),
          ],
        ]);

        final first = await play(agent, runInput('run-1'));
        final second = await play(agent, runInput('run-2'));

        expect(typesOf(first), ['RUN_STARTED', 'RUN_ERROR']);
        expect(typesOf(second), ['RUN_STARTED', 'RUN_FINISHED']);
      },
    );

    test('answers a run beyond the script with SCRIPT_EXHAUSTED', () async {
      final agent = ScriptedAgent([]);

      final events = await play(agent, runInput('run-1'));

      expect(typesOf(events), ['RUN_STARTED', 'RUN_ERROR']);
      final error = events.last as RunError;
      expect(error.code, 'SCRIPT_EXHAUSTED');
      expect(error.message, contains('all 0 turns were played'));
      expect(agent.isExhausted, isTrue);
    });

    test('a turn that throws fails the test and ends its run with that '
        'error', () async {
      final failure = StateError('Expected: "Dell"');
      final agent = ScriptedAgent([(_) => throw failure]);
      final zoneErrors = <Object>[];
      final streamErrors = <Object>[];
      final events = <WireEvent>[];

      runZonedGuarded(
        () => agent
            .run(runInput('run-1'))
            .listen(events.add, onError: streamErrors.add),
        (error, _) => zoneErrors.add(error),
      );
      await pumpEventQueue();

      expect(zoneErrors, [same(failure)]);
      expect(streamErrors, [same(failure)]);
      expect(events, isEmpty);
    });
  });

  group('ScriptedAgent with mimicAdk', () {
    const transfer = {
      'recipient': 'Anna Kowalska',
      'iban': 'PL61109010140000071219812874',
      'amount': null,
      'title': null,
    };
    const filled = {
      'recipient': 'Anna Kowalska',
      'iban': 'PL61109010140000071219812874',
      'amount': 250.0,
      'title': 'Rent October',
    };
    const userMessage = WireUserMessage(
      'msg-user-1',
      'Send Anna 250 PLN for the October rent',
    );
    final tools = [appTool('request_transfer')];

    // The probe's first run: an agent tool fills the transfer, then the
    // agent proposes it with a tool of the app.
    List<AgentStep> proposeTransfer(RunRequest _) => const [
      AgentStep.runAgentTool(
        'update_transfer',
        args: {'amount': 250.0, 'title': 'Rent October'},
        result: {'status': 'updated', 'transfer': filled},
      ),
      AgentStep.patchState([
        {'op': 'replace', 'path': '/transfer/amount', 'value': 250.0},
        {'op': 'replace', 'path': '/transfer/title', 'value': 'Rent October'},
      ]),
      AgentStep.callTool('request_transfer', filled),
    ];

    RunInput firstRun(String thread) => runInput(
      'run-1',
      thread: thread,
      messages: [userMessage],
      tools: tools,
      state: const {'transfer': transfer},
    );

    test('a run that ends on a tool of the app looks like the captured '
        'transcript A1', () async {
      final agent = ScriptedAgent([proposeTransfer]);

      final events = await play(agent, firstRun('thread-A'));

      final captured = AgUiAdkTranscripts.frames('A1');
      expect(_shapes(events.map((event) => event.json)), _shapes(captured));
      final delta = events.whereType<StateDelta>().single;
      expect(delta.operations, (captured[5]['delta']! as List).cast<Object?>());
      final args = events.whereType<ToolCallArgs>().map((event) => event.delta);
      expect(args, [captured[2]['delta'], captured[7]['delta']]);
      final result = events.whereType<ToolCallResult>().single;
      expect(
        jsonDecode(result.content),
        jsonDecode(captured[4]['content']! as String),
      );
      final snapshot = events.whereType<StateSnapshot>().single.snapshot;
      expect(snapshot['transfer'], filled);
      expect(snapshot['_ag_ui_thread_id'], 'thread-A');
      expect(snapshot['_ag_ui_app_name'], isA<String>());
      expect(snapshot['_ag_ui_user_id'], 'thread_user_thread-A');
      expect(snapshot, isNot(contains('pending_tool_calls')));
    });

    test('the follow-up with the answer looks like the captured transcript '
        'A2, with an empty pending_tool_calls', () async {
      final agent = ScriptedAgent([
        proposeTransfer,
        (_) => const [
          AgentStep.say('request_transfer returned TX-0001. Draft I see.'),
        ],
      ]);
      final first = await play(agent, firstRun('thread-A'));
      final callId = callIdOf(first, 'request_transfer');

      final second = await play(
        agent,
        runInput(
          'run-2',
          thread: 'thread-A',
          messages: [
            ...historyAfter([userMessage], first),
            answer(callId, content: '{"approved":true,"transferId":"TX-0001"}'),
          ],
          tools: tools,
          state: const {'transfer': filled},
        ),
      );

      final shapes = _shapes(second.map((event) => event.json));
      expect(shapes, _shapes(AgUiAdkTranscripts.frames('A2')));
      final snapshot = second.whereType<StateSnapshot>().single.snapshot;
      expect(snapshot['pending_tool_calls'], isEmpty);
      expect(snapshot['transfer'], filled);
    });

    test('a follow-up that answers and calls again looks like the captured '
        'transcript B2', () async {
      const changed = {
        'recipient': 'Anna Kowalska',
        'iban': 'PL61109010140000071219812874',
        'amount': 300.0,
        'title': 'Rent October',
      };
      final agent = ScriptedAgent([
        proposeTransfer,
        (_) => const [AgentStep.callTool('request_transfer', changed)],
      ]);
      final first = await play(agent, firstRun('thread-B'));
      final callId = callIdOf(first, 'request_transfer');

      final second = await play(
        agent,
        runInput(
          'run-2',
          thread: 'thread-B',
          messages: [
            ...historyAfter([userMessage], first),
            answer(
              callId,
              content: '{"approved":false,"reason":"draft_changed"}',
            ),
          ],
          tools: tools,
          state: const {'transfer': changed},
        ),
      );

      final shapes = _shapes(second.map((event) => event.json));
      expect(shapes, _shapes(AgUiAdkTranscripts.frames('B2')));
      final snapshot = second.whereType<StateSnapshot>().single.snapshot;
      expect(snapshot['transfer'], changed);
      // Stale: the new call is added only after the snapshot.
      expect(snapshot['pending_tool_calls'], isEmpty);
    });

    test('pending_tool_calls keeps a call the app did not answer, as in the '
        'captured transcript E2', () async {
      final agent = ScriptedAgent(checkProtocol: false, [
        proposeTransfer,
        (_) => const [AgentStep.say('You wrote something else.')],
      ]);
      final first = await play(agent, firstRun('thread-E'));
      final callId = callIdOf(first, 'request_transfer');

      final second = await play(
        agent,
        runInput(
          'run-2',
          thread: 'thread-E',
          messages: [
            ...historyAfter([userMessage], first),
            const WireUserMessage('msg-user-2', 'Wait, what is the IBAN?'),
          ],
          tools: tools,
          state: const {'transfer': filled},
        ),
      );

      final shapes = _shapes(second.map((event) => event.json));
      expect(shapes, _shapes(AgUiAdkTranscripts.frames('E2')));
      final snapshot = second.whereType<StateSnapshot>().single.snapshot;
      expect(snapshot['pending_tool_calls'], [callId]);
    });

    test('a call without arguments has no TOOL_CALL_ARGS, and every call '
        'of the app ends after the final snapshot', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
          AgentStep.callTool('place_order'),
        ],
      ]);

      final events = await play(
        agent,
        runInput(
          'run-1',
          tools: [appTool('search_catalog'), appTool('place_order')],
        ),
      );

      expect(typesOf(events), [
        'RUN_STARTED',
        'TOOL_CALL_START',
        'TOOL_CALL_ARGS',
        'TOOL_CALL_START',
        'STATE_SNAPSHOT',
        'TOOL_CALL_END',
        'TOOL_CALL_END',
        'RUN_FINISHED',
      ]);
      final starts = events.whereType<ToolCallStart>().toList();
      expect(starts.map((event) => event.parentMessageId), [null, null]);
      expect(starts.map((event) => event.json.keys.toSet()), [
        {'type', 'toolCallId', 'toolCallName'},
        {'type', 'toolCallId', 'toolCallName'},
      ]);
      expect(events.whereType<ToolCallEnd>().map((event) => event.toolCallId), [
        starts[0].toolCallId,
        starts[1].toolCallId,
      ]);
    });

    test(
      'an agent tool ends with TOOL_CALL_RESULT holding a JSON object',
      () async {
        final agent = ScriptedAgent([
          (_) => const [
            AgentStep.runAgentTool('find_customer', result: 'C-7'),
            AgentStep.runAgentTool('count_lines', args: {'order': 'A'}),
          ],
        ]);

        final events = await play(agent, runInput('run-1'));

        expect(typesOf(events), [
          'RUN_STARTED',
          'TOOL_CALL_START',
          'TOOL_CALL_END',
          'TOOL_CALL_RESULT',
          'TOOL_CALL_START',
          'TOOL_CALL_ARGS',
          'TOOL_CALL_END',
          'TOOL_CALL_RESULT',
          'STATE_SNAPSHOT',
          'RUN_FINISHED',
        ]);
        final results = events.whereType<ToolCallResult>().toList();
        expect(results.map((event) => jsonDecode(event.content)), [
          {'result': 'C-7'},
          {'result': null},
        ]);
        expect(results[0].json.keys.toSet(), {
          'type',
          'messageId',
          'toolCallId',
          'content',
        });
        expect(results[0].messageId, isNot(results[1].messageId));
      },
    );

    test(
      'sends a patch as whole top-level adds of the patched document',
      () async {
        final agent = ScriptedAgent([
          (_) => const [
            AgentStep.patchState([
              {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
              {'op': 'remove', 'path': '/discount'},
              {'op': 'test', 'path': '/customer', 'value': 'C-7'},
            ]),
            AgentStep.patchState([
              {'op': 'test', 'path': '/customer', 'value': 'C-7'},
            ]),
          ],
        ]);

        final events = await play(
          agent,
          runInput(
            'run-1',
            state: const {
              'order': {
                'lines': [
                  {'sku': 'HDMI-2M', 'quantity': 40},
                ],
                'notes': '',
              },
              'discount': 5,
              'customer': 'C-7',
            },
          ),
        );

        final delta = events.whereType<StateDelta>().single;
        expect(delta.operations, [
          {
            'op': 'add',
            'path': '/order',
            'value': {
              'lines': [
                {'sku': 'HDMI-2M', 'quantity': 40},
              ],
              'notes': 'Urgent',
            },
          },
          // ag-ui-adk cannot delete a key; it stores null.
          {'op': 'add', 'path': '/discount', 'value': null},
        ]);
        final snapshot = events.whereType<StateSnapshot>().single.snapshot;
        expect(snapshot['order'], delta.operations[0]['value']);
        expect(snapshot, containsPair('discount', null));
        expect(snapshot['customer'], 'C-7');
      },
    );

    test('a patch that does not apply fails the test', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.patchState([
            {'op': 'replace', 'path': '/order/lines/7/quantity', 'value': 1},
          ]),
        ],
      ]);
      final zoneErrors = <Object>[];
      final streamErrors = <Object>[];
      final events = <WireEvent>[];

      runZonedGuarded(
        () => agent
            .run(runInput('run-1', state: const {'order': <String, Object?>{}}))
            .listen(events.add, onError: streamErrors.add),
        (error, _) => zoneErrors.add(error),
      );
      await pumpEventQueue();

      expect(zoneErrors, [
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('mimicAdk: false'),
        ),
      ]);
      expect(streamErrors, zoneErrors);
      expect(typesOf(events), ['RUN_STARTED']);
    });

    test('a snapshot keeps the backend keys', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.setState({
            'order': {'notes': 'Urgent'},
          }),
        ],
      ]);

      final events = await play(
        agent,
        runInput('run-1', state: const {'order': <String, Object?>{}}),
      );

      final snapshots = events.whereType<StateSnapshot>().toList();
      expect(snapshots, hasLength(2));
      for (final snapshot in snapshots) {
        expect(snapshot.snapshot, {
          'order': {'notes': 'Urgent'},
          '_ag_ui_thread_id': threadId,
          '_ag_ui_app_name': snapshots.first.snapshot['_ag_ui_app_name'],
          '_ag_ui_user_id': 'thread_user_$threadId',
        });
      }
    });

    test('merges the app state shallowly, per top-level key, at the start of '
        'every run', () async {
      final agent = ScriptedAgent(checkProtocol: false, [
        (_) => const [],
        (_) => const [],
      ]);

      await play(
        agent,
        runInput(
          'run-1',
          state: const {
            'order': {'notes': 'Urgent', 'customer': 'C-7'},
            'filter': 'monitors',
          },
        ),
      );
      final second = await play(
        agent,
        runInput(
          'run-2',
          state: const {
            'order': {'notes': ''},
            '_ag_ui_thread_id': 'from the app',
          },
        ),
      );

      final snapshot = second.whereType<StateSnapshot>().single.snapshot;
      expect(snapshot['order'], {'notes': ''});
      expect(snapshot['filter'], 'monitors');
      // ag-ui-adk ignores the `_ag_ui_*` keys a client sends.
      expect(snapshot['_ag_ui_thread_id'], threadId);
    });
  });

  group('ScriptedAgent without mimicAdk', () {
    test('behaves like a plain AG-UI backend', () async {
      final agent = ScriptedAgent(mimicAdk: false, [
        (_) => const [
          AgentStep.callTool('search_catalog'),
          AgentStep.say('Here is what I found.'),
          AgentStep.callTool('place_order', {'sku': 'HDMI-2M'}),
          AgentStep.runAgentTool('find_customer', result: 'C-7'),
          AgentStep.setState({
            'order': {'notes': ''},
          }),
          AgentStep.patchState([
            {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
          ]),
        ],
      ]);

      final events = await play(
        agent,
        runInput(
          'run-1',
          tools: [appTool('search_catalog'), appTool('place_order')],
        ),
      );

      expect(events.first.json, {
        'type': 'RUN_STARTED',
        'threadId': threadId,
        'runId': 'run-1',
      });
      final starts = events.whereType<ToolCallStart>().toList();
      final textId = events.whereType<TextStart>().single.messageId;
      expect(starts[0].parentMessageId, isNotNull);
      expect(starts[0].parentMessageId, isNot(starts[0].toolCallId));
      expect(starts[1].parentMessageId, textId);
      expect(starts[2].parentMessageId, textId);
      String argumentsOf(ToolCallStart start) => events
          .whereType<ToolCallArgs>()
          .where((event) => event.toolCallId == start.toolCallId)
          .map((event) => event.delta)
          .join();
      expect(argumentsOf(starts[0]), '{}');
      expect(argumentsOf(starts[1]), '{"sku":"HDMI-2M"}');
      expect(
        events.whereType<ToolCallArgs>().where(
          (event) => event.toolCallId == starts[1].toolCallId,
        ),
        hasLength(2),
      );
      final result = events.whereType<ToolCallResult>().single;
      expect(result.content, 'C-7');
      expect(result.json['role'], 'tool');
      expect(events.whereType<StateSnapshot>().single.snapshot, {
        'order': {'notes': ''},
      });
      expect(events.whereType<StateDelta>().single.operations, [
        {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
      ]);
      expect(typesOf(events).sublist(events.length - 3), [
        'STATE_SNAPSHOT',
        'STATE_DELTA',
        'RUN_FINISHED',
      ]);
    });
  });

  group('ScriptedAgent with checkProtocol', () {
    final tools = [appTool('search_catalog'), appTool('place_order')];

    test('accepts a session that keeps the rules', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.say('Looking it up.'),
          AgentStep.runAgentTool(
            'find_customer',
            args: {'name': 'Acme'},
            result: {'id': 'C-7'},
          ),
          AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
        ],
        (_) => const [AgentStep.callTool('place_order')],
        (_) => const [AgentStep.say('Placed.')],
      ]);

      final first = await play(agent, runInput('run-1', tools: tools));
      final history = historyAfter([firstUserMessage], first);
      final second = await play(
        agent,
        runInput(
          'run-2',
          messages: [...history, answer(callIdOf(first, 'search_catalog'))],
          tools: tools,
        ),
      );
      final third = await play(
        agent,
        runInput(
          'run-3',
          messages: [
            ...historyAfter(agent.requests[1].input.messages, second),
            answer(
              callIdOf(second, 'place_order'),
              content: '{"status":"dismissed","approved":false}',
            ),
            const WireUserMessage('user-2', 'Never mind, I will do it.'),
          ],
          tools: tools,
        ),
      );

      for (final events in [first, second, third]) {
        expect(events.whereType<RunError>(), isEmpty);
      }
      expect(agent.isExhausted, isTrue);
    });

    test('rejects a request without playing its turn', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Hello.')],
      ]);

      final rejected = await play(
        agent,
        runInput('run-1', state: const {'pending_tool_calls': <Object?>[]}),
      );
      final accepted = await play(agent, runInput('run-2'));

      expect(typesOf(rejected), ['RUN_ERROR']);
      expect((rejected.single as RunError).code, 'PROTOCOL_VIOLATION');
      expect(_text(accepted), 'Hello.');
      expect(agent.requests, hasLength(2));
      expect(agent.isExhausted, isTrue);
    });

    test('rejects another thread id', () async {
      final agent = ScriptedAgent([(_) => const [], (_) => const []]);
      final first = await play(agent, runInput('run-1'));

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          thread: 'thread-2',
          messages: historyAfter([firstUserMessage], first),
        ),
      );

      expect(error, contains('The thread id is "thread-2"'));
      expect(error, contains('"$threadId"'));
    });

    test('rejects a run id that was used before', () async {
      final agent = ScriptedAgent([(_) => const [], (_) => const []]);
      await play(agent, runInput('run-1'));

      final error = await _violation(agent, runInput('run-1'));

      expect(error, contains('The run id "run-1" was already used.'));
    });

    test('rejects a second run while one is streaming', () async {
      final hold = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [AgentStep.waitFor(hold.future)],
        (_) => const [],
      ]);
      final first = play(agent, runInput('run-1'));
      await pumpEventQueue();

      final error = await _violation(agent, runInput('run-2'));
      hold.complete();
      await first;

      expect(
        error,
        contains('Run "run-2" started while run "run-1" was still streaming'),
      );
    });

    test(
      'accepts the next run as soon as the app has the last event',
      () async {
        final agent = ScriptedAgent([(_) => const [], (_) => const []]);
        final second = Completer<List<WireEvent>>();

        agent.run(runInput('run-1')).listen((event) {
          if (event is RunFinished) {
            second.complete(play(agent, runInput('run-2')));
          }
        });

        expect((await second.future).whereType<RunError>(), isEmpty);
      },
    );

    test('rejects keys of the agent backend in the state', () async {
      final agent = ScriptedAgent([(_) => const []]);

      final error = await _violation(
        agent,
        runInput(
          'run-1',
          state: const {
            'order': <String, Object?>{},
            '_ag_ui_thread_id': threadId,
            'pending_tool_calls': <Object?>[],
          },
        ),
      );

      expect(error, contains('"_ag_ui_thread_id", which the agent backend'));
      expect(error, contains('"pending_tool_calls", which the agent backend'));
      expect(error, contains("wipes ag-ui-adk's list of open tool calls"));
    });

    test('rejects a message with the id of a tool call', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('search_catalog')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final callId = callIdOf(first, 'search_catalog');

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            firstUserMessage,
            WireAssistantMessage(
              callId,
              toolCalls: [
                WireToolCall(
                  id: callId,
                  name: 'search_catalog',
                  arguments: '{}',
                ),
              ],
            ),
            answer(callId),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains('The assistant message "$callId" has the id of a tool call.'),
      );
      expect(error, contains('"asst-$callId"'));
    });

    test('rejects a call of an app tool that is not answered', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('place_order')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final callId = callIdOf(first, 'place_order');

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            ...historyAfter([firstUserMessage], first),
            const WireUserMessage('user-2', 'Hello?'),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains('Tool call "$callId" (place_order) is not answered.'),
      );
    });

    test('does not expect the app to answer calls of agent tools', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.event({
            'type': 'TOOL_CALL_START',
            'toolCallId': 'agent-call',
            'toolCallName': 'think',
          }),
          AgentStep.event({
            'type': 'TOOL_CALL_END',
            'toolCallId': 'agent-call',
          }),
        ],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));

      final second = await play(
        agent,
        runInput(
          'run-2',
          messages: [
            ...historyAfter([firstUserMessage], first),
            const WireUserMessage('user-2', 'Go on'),
          ],
          tools: tools,
        ),
      );

      expect(second.whereType<RunError>(), isEmpty);
    });

    test('rejects an answer after the next user message', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('place_order')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final callId = callIdOf(first, 'place_order');

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            ...historyAfter([firstUserMessage], first),
            const WireUserMessage('user-2', 'Hello?'),
            answer(callId),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains(
          'Tool call "$callId" (place_order) is answered only after the user '
          'message "user-2".',
        ),
      );
    });

    test('rejects a call answered twice', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('place_order')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final callId = callIdOf(first, 'place_order');

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            ...historyAfter([firstUserMessage], first),
            answer(callId, id: 'tool-a'),
            answer(callId, id: 'tool-b'),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains(
          'Tool call "$callId" (place_order) is answered 2 times, by '
          '"tool-a", "tool-b".',
        ),
      );
    });

    test('rejects an answer to a call that is not in the history', () async {
      final agent = ScriptedAgent([(_) => const [], (_) => const []]);
      final first = await play(agent, runInput('run-1', tools: tools));

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            ...historyAfter([firstUserMessage], first),
            answer('call-404', id: 'tool-x'),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains(
          'The tool message "tool-x" answers "call-404", but no earlier '
          'assistant message contains that call.',
        ),
      );
    });

    test('rejects a message id used twice', () async {
      final agent = ScriptedAgent([(_) => const []]);

      final error = await _violation(
        agent,
        runInput('run-1', messages: [firstUserMessage, firstUserMessage]),
      );

      expect(
        error,
        contains('The message id "user-1" is used twice in the history.'),
      );
    });

    test('rejects a history without the earlier messages', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Which monitor?')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1'));
      final textId = first.whereType<TextStart>().single.messageId;

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: const [WireUserMessage('user-2', 'The Dell')],
        ),
      );

      expect(
        error,
        contains('The history lacks messages "user-1", "$textId" of earlier'),
      );
    });

    test('rejects earlier messages in another order', () async {
      final agent = ScriptedAgent([(_) => const [], (_) => const []]);
      const second = WireUserMessage('user-2', 'And 12 monitors');
      await play(
        agent,
        runInput('run-1', messages: const [firstUserMessage, second]),
      );

      final error = await _violation(
        agent,
        runInput('run-2', messages: const [second, firstUserMessage]),
      );

      expect(
        error,
        contains(
          'The history changed the order of earlier messages: "user-2" now '
          'comes before "user-1".',
        ),
      );
    });

    test('rejects a changed text of the agent', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Which monitor?')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1'));
      final textId = first.whereType<TextStart>().single.messageId;

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            firstUserMessage,
            WireAssistantMessage(textId, content: 'Which monit'),
          ],
        ),
      );

      expect(
        error,
        contains(
          'The assistant message "$textId" has the text "Which monit" in the '
          'history, but the agent said "Which monitor?".',
        ),
      );
    });

    test('rejects a history without a tool call of the agent', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('search_catalog', {'query': 'x'}),
        ],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final callId = callIdOf(first, 'search_catalog');

      final error = await _violation(
        agent,
        runInput('run-2', messages: [firstUserMessage], tools: tools),
      );

      expect(
        error,
        contains(
          'The history lacks the agent\'s tool call "$callId" '
          '(search_catalog).',
        ),
      );
    });

    test('rejects a tool call with other arguments or name', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('search_catalog', {'query': 'x'}),
        ],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final callId = callIdOf(first, 'search_catalog');

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            firstUserMessage,
            WireAssistantMessage(
              'asst-$callId',
              toolCalls: [
                WireToolCall(id: callId, name: 'place_order', arguments: '{}'),
              ],
            ),
            answer(callId),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains(
          'The tool call "$callId" is named "place_order" in the history, '
          'but the agent called "search_catalog".',
        ),
      );
      expect(
        error,
        contains(
          'The tool call "$callId" has the arguments {} in the history, but '
          'the agent sent {"query":"x"}.',
        ),
      );
    });

    test('rejects a tool call outside its parent message', () async {
      final agent = ScriptedAgent(mimicAdk: false, [
        (_) => const [
          AgentStep.say('Searching.'),
          AgentStep.callTool('search_catalog'),
        ],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1', tools: tools));
      final textId = first.whereType<TextStart>().single.messageId;
      final callId = callIdOf(first, 'search_catalog');

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            firstUserMessage,
            WireAssistantMessage(textId, content: 'Searching.'),
            WireAssistantMessage(
              'asst-$callId',
              toolCalls: [
                WireToolCall(
                  id: callId,
                  name: 'search_catalog',
                  arguments: '{}',
                ),
              ],
            ),
            answer(callId),
          ],
          tools: tools,
        ),
      );

      expect(
        error,
        contains(
          'The tool call "$callId" belongs to the assistant message '
          '"$textId" (its parentMessageId), but the history puts it into '
          '"asst-$callId".',
        ),
      );
    });

    test('rejects a history without the result of an agent tool', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.runAgentTool('find_customer', result: 'C-7')],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1'));
      final resultId = first.whereType<ToolCallResult>().single.messageId;
      final history = historyAfter([firstUserMessage], first);

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: history.where((m) => m is! WireToolMessage).toList(),
        ),
      );

      expect(error, contains('The history lacks message "$resultId"'));
    });

    test('expects only what the app received from a stopped run', () async {
      final resume = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          const AgentStep.say('Before.'),
          AgentStep.waitFor(resume.future),
          const AgentStep.say('After.'),
        ],
        (_) => const [AgentStep.say('Next.')],
      ]);
      final events = <WireEvent>[];
      final subscription = agent.run(runInput('run-1')).listen(events.add);
      await pumpEventQueue();

      await subscription.cancel();
      resume.complete();
      await pumpEventQueue();
      final second = await play(
        agent,
        runInput('run-2', messages: historyAfter([firstUserMessage], events)),
      );

      expect(_text(events), 'Before.');
      expect(events.last, isA<TextEnd>());
      expect(_text(second), 'Next.');
    });

    test('expects the history of a MESSAGES_SNAPSHOT instead', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.event({
            'type': 'MESSAGES_SNAPSHOT',
            'messages': [
              {'id': 'server-1', 'role': 'user', 'content': 'Hi'},
            ],
          }),
          AgentStep.say('Hello.'),
        ],
        (_) => const [],
        (_) => const [],
      ]);
      final first = await play(agent, runInput('run-1'));
      final textId = first.whereType<TextStart>().single.messageId;

      final error = await _violation(
        agent,
        runInput(
          'run-2',
          messages: [
            firstUserMessage,
            WireAssistantMessage(textId, content: 'Hello.'),
          ],
        ),
      );
      final accepted = await play(
        agent,
        runInput(
          'run-3',
          messages: [
            const WireUserMessage('server-1', 'Hi'),
            WireAssistantMessage(textId, content: 'Hello.'),
          ],
        ),
      );

      expect(error, contains('The history lacks message "server-1"'));
      expect(accepted.whereType<RunError>(), isEmpty);
    });

    test('plays a turn for any request without checkProtocol', () async {
      final agent = ScriptedAgent(checkProtocol: false, [
        (_) => const [AgentStep.say('Hello.')],
      ]);

      final events = await play(
        agent,
        runInput('run-1', state: const {'pending_tool_calls': <Object?>[]}),
      );

      expect(_text(events), 'Hello.');
    });
  });

  group('AgentStep.waitFor', () {
    test('pauses the run until the signal completes', () async {
      final signal = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          const AgentStep.say('Before.'),
          AgentStep.waitFor(signal.future),
          const AgentStep.say('After.'),
        ],
      ]);
      final events = <WireEvent>[];
      final done = Completer<void>();

      agent.run(runInput('run-1')).listen(events.add, onDone: done.complete);
      await pumpEventQueue();
      final beforeSignal = events.length;
      expect(_text(events), 'Before.');
      expect(done.isCompleted, isFalse);

      signal.complete();
      await done.future;

      expect(events.length, greaterThan(beforeSignal));
      expect(_text(events), 'Before.After.');
      expect(events.last, isA<RunFinished>());
    });

    test('ends the run with the error of a signal that fails', () async {
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(Future.error(const SocketLikeError())),
          const AgentStep.say('Never said.'),
        ],
      ]);
      final events = <WireEvent>[];

      final error = await agent
          .run(runInput('run-1'))
          .listen(events.add)
          .asFuture<void>()
          .then<Object?>((_) => null, onError: (Object error) => error);

      expect(error, isA<SocketLikeError>());
      expect(typesOf(events), ['RUN_STARTED']);
    });

    test('lets the app stop the run at once', () async {
      final agent = ScriptedAgent([
        (_) => [AgentStep.waitFor(Completer<void>().future)],
      ]);
      final events = <WireEvent>[];
      final subscription = agent.run(runInput('run-1')).listen(events.add);
      await pumpEventQueue();

      // Would never complete if stopping waited for the signal.
      await subscription.cancel();

      expect(typesOf(events), ['RUN_STARTED']);
    });
  });
}

/// A transport failure, as a socket would report it.
final class SocketLikeError implements Exception {
  /// Creates the error.
  const SocketLikeError();

  @override
  String toString() => 'Connection reset by peer';
}

/// Plays [input] and returns the message of its `PROTOCOL_VIOLATION`.
Future<String> _violation(ScriptedAgent agent, RunInput input) async {
  final events = await play(agent, input);
  expect(typesOf(events), ['RUN_ERROR'], reason: '${events.last.json}');
  final error = events.single as RunError;
  expect(error.code, 'PROTOCOL_VIOLATION');
  expect(error.message, startsWith('Run "${input.runId}" broke the AG-UI'));
  return error.message;
}

/// All text the agent said in [events].
String _text(Iterable<WireEvent> events) =>
    events.whereType<TextContent>().map((event) => event.delta).join();

/// What ag-ui-adk's events look like, without their values: the type and
/// keys of every event, the keys of a snapshot and the operations of a
/// delta. Consecutive `TEXT_MESSAGE_CONTENT` events count as one, because
/// how a text is split does not matter.
List<Object?> _shapes(Iterable<Map<String, Object?>> events) {
  final shapes = <Object?>[];
  for (final json in events) {
    final shape = [
      json['type'],
      ...(json.keys.toList()..sort()),
      if (json['snapshot'] case final Map<String, Object?> snapshot)
        snapshot.keys.toSet(),
      if (json['delta'] case final List<Object?> delta)
        for (final operation in delta.cast<Map<String, Object?>>())
          '${operation['op']} ${operation['path']}',
    ];
    if (json['type'] == 'TEXT_MESSAGE_CONTENT' &&
        shapes.isNotEmpty &&
        (shapes.last! as List<Object?>).first == 'TEXT_MESSAGE_CONTENT') {
      continue;
    }
    shapes.add(shape);
  }
  return shapes;
}
