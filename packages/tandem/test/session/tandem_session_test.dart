import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/src/session/view_tool.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/chat_items.dart';
import '../support/connections.dart';
import '../support/reports.dart';
import '../support/run_bodies.dart';
import '../support/shop.dart';

void main() {
  late Shop shop;
  late List<TandemEvent> events;

  setUp(() {
    shop = Shop();
    // Tear-downs run in reverse, so the session is disposed before the shop.
    addTearDown(shop.close);
    events = [];
  });

  List<AgentCall> agentCalls() => [...events.whereType<AgentCall>()];

  TandemSession open(
    AgentConnection connection, {
    void Function(TandemEvent event)? onEvent,
    TandemThread? thread,
  }) {
    final session = TandemSession(
      surface: shop,
      connection: connection,
      onEvent: onEvent ?? events.add,
      thread: thread,
    );
    addTearDown(session.dispose);
    return session;
  }

  /// A session that the test disposes itself, as a screen that closes.
  TandemSession openToClose(TandemThread thread, AgentConnection connection) =>
      TandemSession(surface: shop, connection: connection, thread: thread);

  Future<(TandemThread, ScriptedAgent)> closeAfterFirstReply() async {
    final thread = TandemThread();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    final first = openToClose(thread, agent)..send('a');
    await pumpEventQueue();
    first.dispose();
    return (thread, agent);
  }

  Future<(TandemSession, ScriptedAgent)> askToClear() async {
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
      (_) => const [AgentStep.say('Cleared.')],
    ]);
    final session = open(agent)..send('clear it');
    await pumpEventQueue();
    return (session, agent);
  }

  Future<(TandemSession, ScriptedAgent, Completer<void>)> askToRefresh() async {
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('refresh')],
      (_) => const [AgentStep.say('Up to date.')],
    ]);
    final session = open(agent)..send('refresh');
    await pumpEventQueue();
    return (session, agent, serverReply);
  }

  /// The messages of the thread once [events] played as its first run.
  Future<List<Map<String, Object?>>> threadAfter(
    List<Map<String, Object?>> events,
  ) async {
    final connection = RawFirstRun(
      Stream.fromIterable([
        ...events,
        {
          'type': 'RUN_FINISHED',
          'metadata': {'runOnly': true},
        },
      ]),
      ScriptedAgent.repeating((_) => const [AgentStep.say('Done.')]),
    );
    final session = open(connection)..send('add milk');
    await pumpEventQueue();
    session.send('and bread');
    await pumpEventQueue();
    return messagesOf(connection.requests.last);
  }

  test('the text events of a message merge their metadata into it, and a '
      'later key replaces an earlier one', () async {
    final messages = await threadAfter([
      {
        'type': 'TEXT_MESSAGE_START',
        'messageId': 'm1',
        'metadata': {
          'stage': 'start',
          'replaced': {'old': true},
        },
      },
      {
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': 'm1',
        'delta': 'Adding.',
        'metadata': {'stage': 'content', 'nullable': null},
      },
      {
        'type': 'TEXT_MESSAGE_END',
        'messageId': 'm1',
        'metadata': {
          'stage': 'end',
          'replaced': {'new': true},
        },
      },
    ]);

    expect(messages.singleWhere((message) => message['id'] == 'm1'), {
      'id': 'm1',
      'role': 'assistant',
      'content': 'Adding.',
      'metadata': {
        'stage': 'end',
        'replaced': {'new': true},
        'nullable': null,
      },
    });
  });

  test('the events of a tool call merge their metadata into the call, and a '
      'result keeps its own', () async {
    final messages = await threadAfter([
      {
        'type': 'TOOL_CALL_START',
        'toolCallId': 'b1',
        'toolCallName': 'lookup',
        'parentMessageId': 'm1',
        'metadata': {'owner': 'backend'},
      },
      {
        'type': 'TOOL_CALL_RESULT',
        'messageId': 'r1',
        'toolCallId': 'b1',
        'content': '[]',
        'metadata': {'source': 'catalog'},
      },
      {
        'type': 'TOOL_CALL_START',
        'toolCallId': 'c1',
        'toolCallName': 'add',
        'parentMessageId': 'm1',
        'metadata': {
          'owner': 'app',
          'replaced': {'old': true},
        },
      },
      {
        'type': 'TOOL_CALL_ARGS',
        'toolCallId': 'c1',
        'delta': '{"item":"milk"}',
        'metadata': {
          'replaced': {'new': true},
        },
      },
      {
        'type': 'TOOL_CALL_END',
        'toolCallId': 'c1',
        'metadata': {'signature': 'opaque-call'},
      },
    ]);

    expect(messages.singleWhere((message) => message['id'] == 'm1'), {
      'id': 'm1',
      'role': 'assistant',
      'toolCalls': [
        {
          'id': 'b1',
          'type': 'function',
          'function': {'name': 'lookup', 'arguments': '{}'},
          'metadata': {'owner': 'backend'},
        },
        {
          'id': 'c1',
          'type': 'function',
          'function': {'name': 'add', 'arguments': '{"item":"milk"}'},
          'metadata': {
            'owner': 'app',
            'replaced': {'new': true},
            'signature': 'opaque-call',
          },
        },
      ],
    });
    expect(
      messages.singleWhere((message) => message['id'] == 'r1')['metadata'],
      {'source': 'catalog'},
    );
  });

  test('metadata in the thread is a copy that nobody can change', () async {
    final sent = <Object?>[1, null];
    final messages = await threadAfter([
      {
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': 'm1',
        'delta': 'Adding.',
        'metadata': {'values': sent},
      },
    ]);
    sent.add(2);

    final {'metadata': metadata as Map<String, Object?>} = messages.singleWhere(
      (message) => message['id'] == 'm1',
    );
    final {'values': values as List<Object?>} = metadata;
    expect(values, [1, null]);
    expect(() => metadata['values'] = 0, throwsUnsupportedError);
    expect(() => values.add(2), throwsUnsupportedError);
  });

  test(
    'a tool-only message keeps its metadata through reset and session handoff',
    () async {
      shop.add('milk');
      final connection = RawFirstRun(
        Stream.fromIterable([
          {
            'type': 'TEXT_MESSAGE_START',
            'messageId': 'm1',
            'metadata': {'stage': 'start'},
          },
          {
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': 'm1',
            'delta': '',
            'metadata': {'emptyDelta': true},
          },
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'clear',
            'parentMessageId': 'm1',
          },
          {
            'type': 'TOOL_CALL_END',
            'toolCallId': 'c1',
            'metadata': {'signature': 'opaque-call'},
          },
          {
            'type': 'TEXT_MESSAGE_END',
            'messageId': 'm1',
            'metadata': {'stage': 'end', 'signature': 'opaque-message'},
          },
          {'type': 'RUN_FINISHED'},
        ]),
        ScriptedAgent([
          (_) => const [AgentStep.say('Kept.')],
        ]),
      );
      final thread = TandemThread(id: ThreadId('metadata-handoff'));
      final first = openToClose(thread, connection)..send('clear it');
      await pumpEventQueue();
      expect(first.items.whereType<AgentMessage>(), isEmpty);
      expect(_card(first).status, ApprovalStatus.pending);
      first
        ..startOver()
        ..dispose();
      final next = open(connection, thread: thread)..send('keep it');
      await pumpEventQueue();

      expect(messagesOf(connection.requests[1]).first, {
        'id': 'm1',
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'c1',
            'type': 'function',
            'function': {'name': 'clear', 'arguments': '{}'},
            'metadata': {'signature': 'opaque-call'},
          },
        ],
        'metadata': {
          'stage': 'end',
          'emptyDelta': true,
          'signature': 'opaque-message',
        },
      });
      expect(linesOf(connection.requests[1]), [
        'c1 clear {}',
        'c1 -> {"status":"cancelled"}',
        'user: keep it',
      ]);
      expect(next.items.whereType<AgentMessage>().single.text, 'Kept.');
      expect(shop.items, ['milk']);
    },
  );

  for (final ending in ['RUN_FINISHED', 'RUN_ERROR']) {
    test(
      'interleaved messages retain their opening order after $ending',
      () async {
        collectReports();
        for (final metadata in [null, const <String, Object?>{}]) {
          final connection = RawFirstRun(
            Stream<Map<String, Object?>>.fromIterable([
              {
                'type': 'TEXT_MESSAGE_CHUNK',
                'subagentRunId': 'finder',
                'messageId': 'first',
                'metadata': ?metadata,
              },
              {
                'type': 'TEXT_MESSAGE_CHUNK',
                'subagentRunId': 'checker',
                'messageId': 'second',
                'delta': 'Checked.',
              },
              {
                'type': 'TEXT_MESSAGE_CHUNK',
                'subagentRunId': 'finder',
                'delta': 'Found.',
              },
              {'type': ending},
            ]).transform(agUiRun(const {})),
            ScriptedAgent([
              (_) => const [AgentStep.say('Done.')],
            ]),
          );
          final session = open(connection)..send('search');
          await pumpEventQueue();
          session.send('again');
          await pumpEventQueue();

          expect(linesOf(connection.requests[1]), [
            'user: search',
            'assistant: Found.',
            'assistant: Checked.',
            'user: again',
          ]);
        }
      },
    );
  }

  for (final stopped in [false, true]) {
    test('a ${stopped ? 'stopped' : 'failed'} message keeps metadata with only '
        'the text that was shown', () async {
      collectReports();
      final source = StreamController<Map<String, Object?>>();
      final connection = RawFirstRun(
        source.stream,
        ScriptedAgent([
          (_) => const [AgentStep.say('Again.')],
        ]),
      );
      final session = open(connection)..send('hello');
      source.add({
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': 'm1',
        'delta': 'Visible.',
        'metadata': {'stage': 'partial'},
      });
      await pumpEventQueue();
      if (stopped) {
        session.stop();
        source.add({
          'type': 'TEXT_MESSAGE_CONTENT',
          'messageId': 'm1',
          'delta': 'Hidden.',
          'metadata': {'hiddenChunk': true},
        });
      }
      source
        ..add({
          'type': 'TEXT_MESSAGE_END',
          'messageId': 'm1',
          'metadata': {'stage': 'ended'},
        })
        ..add({'type': stopped ? 'RUN_FINISHED' : 'RUN_ERROR'});
      await source.close();
      await pumpEventQueue();
      session.send('again');
      await pumpEventQueue();

      expect(messagesOf(connection.requests[1])[1], {
        'id': 'm1',
        'role': 'assistant',
        'content': 'Visible.',
        'metadata': {'stage': 'ended', if (stopped) 'hiddenChunk': true},
      });
    });
  }

  test('a call runs at once and its result goes in the next run', () async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Done.')],
    ]);
    final session = open(agent)..send('add milk');
    await pumpEventQueue();

    expect(shop.items, ['milk']);
    expect(agent.requests, hasLength(2));
    expect(linesOf(agent.requests[1]), [
      'user: add milk',
      'call-1 add {"item":"milk"}',
      'call-1 -> null',
    ]);
    final [AgentCall(:tool, :arguments, :result)] = agentCalls();
    expect((tool, result), ('add', null));
    expect(arguments, {'item': 'milk'});
    expect(summaryOf(session.items), [
      ('user', 'add milk'),
      ('agent', 'Done.', false),
    ]);
  });

  test('calls go back in the message the server names, and its own calls with their results', () async {
    final connection = RawFirstRun(
      Stream.fromIterable([
        _toolStart('b1', 'find_customer', parent: 'm1'),
        _toolArgs('b1', '{"q":"A"}'),
        {
          'type': 'TOOL_CALL_RESULT',
          'messageId': 'r1',
          'toolCallId': 'b1',
          'content': '[]',
        },
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm2', 'delta': 'Adding.'},
        _toolStart('c1', 'add', parent: 'm2'),
        _toolArgs('c1', '{"item":"x"}'),
        // No result: the server's call stays out.
        _toolStart('b2', 'lookup', parent: 'm2'),
        _toolStart('b3', 'lookup'),
        {'type': 'RUN_FINISHED'},
      ]),
      ScriptedAgent([
        (_) => const [AgentStep.say('Done.')],
      ]),
    );
    open(connection).send('go');
    await pumpEventQueue();

    expect(shop.items, ['x']);
    final history = messagesOf(connection.requests[1]).skip(1).toList();
    expect(history.map((message) => message['id']), [
      'm1',
      'r1',
      'm2',
      isA<String>(),
    ]);
    expect(history[2]['content'], 'Adding.');
    expect(linesOf(connection.requests[1]).skip(1), [
      'b1 find_customer {"q":"A"}',
      'b1 -> []',
      'c1 add {"item":"x"}',
      'c1 -> null',
    ]);
  });

  test('a run is Thinking until it ends, then Idle', () async {
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(gate.future), const AgentStep.say('Hi')],
    ]);
    final session = open(agent)..send('hi');
    await pumpEventQueue();
    expect(session.status, isA<Thinking>());

    gate.complete();
    await pumpEventQueue();
    expect(session.status, isA<Idle>());
  });

  test('chunked calls reach the session with their parent message', () async {
    final connection = RawFirstRun(
      Stream<Map<String, Object?>>.fromIterable([
        {'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm1', 'delta': 'Adding.'},
        {
          'type': 'TOOL_CALL_CHUNK',
          'toolCallId': 'c1',
          'toolCallName': 'add',
          'parentMessageId': 'm1',
          'delta': '{"item":',
        },
        {'type': 'TOOL_CALL_CHUNK', 'delta': '"x"}'},
        {'type': 'RUN_FINISHED'},
      ]).transform(agUiRun(const {})),
      ScriptedAgent([
        (_) => const [AgentStep.say('Done.')],
      ]),
    );
    open(connection).send('go');
    await pumpEventQueue();

    expect(shop.items, ['x']);
    final history = messagesOf(connection.requests[1]);
    expect(history[1]['id'], 'm1');
    expect(history[1]['content'], 'Adding.');
    expect(linesOf(connection.requests[1]).skip(1), [
      'c1 add {"item":"x"}',
      'c1 -> null',
    ]);
  });

  test('Thinking names a tool of the backend from its start until its result '
      'or the next text', () async {
    final stream = StreamController<Map<String, Object?>>();
    addTearDown(stream.close);
    final session = open(RawFirstRun(stream.stream, ScriptedAgent([])))
      ..send('find a monitor');
    final statuses = <SessionStatus>[];
    session.addListener(() {
      if (statuses.lastOrNull != session.status) {
        statuses.add(session.status);
      }
    });

    for (final event in [
      _toolStart('c1', 'search_catalog'),
      {
        'type': 'TOOL_CALL_RESULT',
        'messageId': 'r1',
        'toolCallId': 'c1',
        'content': '[]',
      },
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c2', 'toolCallName': 'lookup'},
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'None.'},
    ]) {
      stream.add(event);
      await pumpEventQueue();
    }

    expect(statuses, const [
      Thinking(backendTool: 'search_catalog'),
      Thinking(),
      Thinking(backendTool: 'lookup'),
      Thinking(),
    ]);
  });

  test('statuses that say the same are equal, also when not const', () {
    // An app may build a status at runtime.
    // ignore: prefer_const_constructors
    expect([Idle(), Stopping()], const [Idle(), Stopping()]);
  });

  test('a call without approval is Calling while it runs, then Idle', () async {
    final (session, _, serverReply) = await askToRefresh();
    expect(
      session.status,
      isA<Calling>()
          .having((status) => status.tool, 'tool', 'refresh')
          .having((status) => status.approved, 'approved', isFalse),
    );

    serverReply.complete();
    await pumpEventQueue();
    expect(session.status, isA<Idle>());
  });

  test('Stop during a call without approval stops the run', () async {
    final (session, agent, serverReply) = await askToRefresh();

    session.stop();
    expect(session.status, isA<Stopping>());
    serverReply.complete();
    await pumpEventQueue();

    expect(agent.requests, hasLength(1));
    expect(session.status, isA<Idle>());
  });

  test('Stop hides the rest of the run, runs nothing from it, and the next '
      'message waits', () async {
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        const AgentStep.say('Working'),
        AgentStep.waitFor(gate.future),
        const AgentStep.say(' more'),
        const AgentStep.callTool('add', {'item': 'x'}),
      ],
      (_) => const [AgentStep.say('Hi')],
    ]);
    final session = open(agent)..send('go');
    await pumpEventQueue();
    expect(summaryOf(session.items), [
      ('user', 'go'),
      ('agent', 'Working', false),
    ]);

    session.stop();
    expect(session.status, isA<Stopping>());
    session.send('next');
    expect(agent.requests, hasLength(1));
    gate.complete();
    await pumpEventQueue();

    expect(shop.items, isEmpty);
    expect(summaryOf(session.items), [
      ('user', 'go'),
      ('agent', 'Working', true),
      ('user', 'next'),
      ('agent', 'Hi', false),
    ]);
    expect(events, [isA<RunStopped>()]);
    expect(linesOf(agent.requests[1]), [
      'user: go',
      'assistant: Working',
      'call-1 add {"item":"x"}',
      'call-1 -> {"status":"cancelled"}',
      'user: next',
    ]);
    expect(agent.requests, hasLength(2));
  });

  for (final (ending, end, reports) in [
    (
      'the outcome cancelled',
      {
        'type': 'RUN_FINISHED',
        'outcome': {'type': 'cancelled'},
      },
      isEmpty,
    ),
    (
      'RUN_ERROR',
      {'type': 'RUN_ERROR', 'message': 'Cancelled.'},
      [isA<AgentRunException>()],
    ),
  ]) {
    test('Stop tells a stoppable connection once, and the run its server ends '
        'with $ending stops quietly', () async {
      final reported = collectReports();
      final connection = StoppableAgent(end);
      final session = open(connection)..send('go');
      await pumpEventQueue();

      session
        ..stop()
        ..stop();
      expect(session.status, isA<Stopping>());
      await pumpEventQueue();

      expect(connection.stopped.single, same(connection.requests.single));
      expect(session.status, isA<Idle>());
      expect(summaryOf(session.items), [
        ('user', 'go'),
        ChatNoticeKind.stopped,
      ]);
      expect(events, [isA<RunStopped>()]);
      expect(reported.map((details) => details.exception), reports);
    });
  }

  test('a RUN_ERROR after Stop fails the run on a connection that cannot '
      'stop it on its server', () async {
    final reported = collectReports();
    final run = StreamController<Map<String, Object?>>();
    final session = open(RawFirstRun(run.stream, ScriptedAgent([])))
      ..send('go');
    await pumpEventQueue();

    session.stop();
    run.add({'type': 'RUN_ERROR', 'message': 'Cancelled.'});
    await run.close();
    await pumpEventQueue();

    expect(reported, hasLength(1));
    expect(summaryOf(session.items).last, ChatNoticeKind.runFailed);
    expect(events, [isA<RunStopped>(), isA<RunFailed>()]);
  });

  test('a RUN_ERROR after a stop that failed fails the run', () async {
    final reported = collectReports();
    final connection = StoppableAgent(const {
      'type': 'RUN_ERROR',
      'message': 'Out of quota.',
    }, failsToStop: true);
    final session = open(connection)..send('go');
    await pumpEventQueue();

    session.stop();
    await pumpEventQueue();
    await connection.end();
    await pumpEventQueue();

    expect(reported.map((details) => details.exception), [
      isA<StateError>(),
      isA<AgentRunException>(),
    ]);
    expect(summaryOf(session.items).last, ChatNoticeKind.runFailed);
    expect(events, [isA<RunStopped>(), isA<RunFailed>()]);
  });

  test('a session disposed on RunStopped does not tell the connection to '
      'stop', () async {
    final connection = StoppableAgent(const {'type': 'RUN_FINISHED'});
    late final TandemSession session;
    session = TandemSession(
      surface: shop,
      connection: connection,
      onEvent: (event) {
        if (event is RunStopped) {
          session.dispose();
        }
      },
    )..send('go');
    await pumpEventQueue();

    session.stop();
    await pumpEventQueue();

    expect(connection.stopped, isEmpty);
  });

  test('a run the server cancels on its own does not tell a stoppable '
      'connection to stop', () async {
    final connection = StoppableAgent(const {
      'type': 'RUN_FINISHED',
      'outcome': {'type': 'cancelled'},
    });
    open(connection).send('go');
    await pumpEventQueue();

    await connection.end();
    await pumpEventQueue();

    expect(connection.stopped, isEmpty);
    expect(events, [isA<RunStopped>()]);
  });

  test(
    'a ToolCallRefused is refused, others are reported; the next message works',
    () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('add', {'item': ''}),
          AgentStep.callTool('remove_at', {'index': 0}),
        ],
        (_) => const [AgentStep.fail('boom')],
        (_) => const [AgentStep.say('Hi')],
      ]);
      final reported = collectReports();
      final session = open(agent)..send('a');
      await pumpEventQueue();

      final messages = messagesOf(agent.requests[1]);
      final [..., {'content': refused as String}, _] = messages;
      final [..., {'content': failed as String}] = messages;
      expect(jsonDecode(refused), {
        'status': 'refused',
        'reason': contains('item'),
      });
      expect(failed, ToolAnswer.failed.content);
      expect(reported.map((details) => details.exception), [
        isRangeError,
        isA<AgentRunException>().having(
          (err) => err.message,
          'message',
          'boom',
        ),
      ]);
      expect(events, [isA<RunFailed>()]);
      expect(summaryOf(session.items), [
        ('user', 'a'),
        ChatNoticeKind.runFailed,
      ]);

      session.send('b');
      await pumpEventQueue();
      expect(summaryOf(session.items).last, ('agent', 'Hi', false));
      // A run that ended with RUN_ERROR keeps its thread and history.
      expect(agent.requests[2]['threadId'], agent.requests[0]['threadId']);
      expect(linesOf(agent.requests[2]), [
        ...linesOf(agent.requests[1]),
        'user: b',
      ]);
    },
  );

  test('onEvent can send at once after a failed run', () async {
    collectReports();
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(gate.future), const AgentStep.say('Back.')],
    ]);
    shop.listThrows = true;
    late final TandemSession session;
    session = open(
      agent,
      onEvent: (event) {
        if (event is RunFailed) {
          shop.listThrows = false;
          session.send('again');
        }
      },
    );

    session.send('hi');
    await pumpEventQueue();
    expect(session.status, isA<Thinking>());

    gate.complete();
    await pumpEventQueue();
    expect(linesOf(agent.requests.single), ['user: hi\n\nagain']);
    expect(session.status, isA<Idle>());
  });

  test('onEvent can dispose the session on a run that failed to open', () {
    collectReports();
    // Not open(), which would dispose it again at the end.
    late final TandemSession session;
    session = TandemSession(
      surface: shop,
      connection: ThrowsFirst(ScriptedAgent(const [])),
      onEvent: (event) => session.dispose(),
    );

    expect(() => session.send('hi'), returnsNormally);
  });

  test('startOver after a failed run sends the next message to a new thread '
      'without the earlier history', () async {
    collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi')],
      (_) => const [AgentStep.fail('Too long.')],
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    late final TandemSession session;
    session = open(
      agent,
      onEvent: (event) {
        events.add(event);
        if (event case RunFailed(code: ScriptedErrorCode.scripted)) {
          session.startOver();
        }
      },
    );

    session.send('a');
    await pumpEventQueue();
    session.send('b');
    await pumpEventQueue();
    session.send('c');
    await pumpEventQueue();

    expect(events, [isA<RunFailed>()]);
    expect(agent.requests[2]['threadId'], isNot(agent.requests[1]['threadId']));
    expect(linesOf(agent.requests[2]), ['user: c']);
    expect(summaryOf(session.items), [
      ('user', 'a'),
      ('agent', 'Hi', false),
      ('user', 'b'),
      ChatNoticeKind.runFailed,
      ChatNoticeKind.startedOver,
      ('user', 'c'),
      ('agent', 'Fresh.', false),
    ]);
  });

  test('startOver keeps a message whose run never went out', () async {
    collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    shop.listThrows = true;
    late final TandemSession session;
    session = open(
      agent,
      onEvent: (event) {
        if (event is RunFailed) {
          shop.listThrows = false;
          session.startOver();
        }
      },
    );

    session.send('hi');
    await pumpEventQueue();
    session.send('again');
    await pumpEventQueue();

    expect(linesOf(agent.requests.single), ['user: hi\n\nagain']);
  });

  test('startOver keeps a message whose connection threw before the run went '
      'out', () async {
    collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    late final TandemSession session;
    session = open(
      ThrowsFirst(agent),
      onEvent: (event) {
        if (event is RunFailed) {
          session.startOver();
        }
      },
    );

    session.send('hi');
    await pumpEventQueue();
    session.send('again');
    await pumpEventQueue();

    expect(linesOf(agent.requests.single), ['user: hi\n\nagain']);
  });

  test('startOver cancels a waiting request, and does nothing while a run is '
      'open', () async {
    final (session, agent) = await askToClear();

    session.startOver();
    expect(_card(session).status, ApprovalStatus.cancelled);
    expect(session.status, isA<Idle>());

    session
      ..send('again')
      ..startOver();
    expect(summaryOf(session.items).last, ('user', 'again'));
    await pumpEventQueue();
    expect(linesOf(agent.requests.last), ['user: again']);
  });

  for (final reopen in [false, true]) {
    test('an app-id thread sends unsent results with their calls after '
        '${reopen ? 'reopening on a changed screen' : 'startOver'}', () async {
      shop.add('milk');
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.say('Checking the list.'),
          AgentStep.stateSnapshot({'step': 1}),
          AgentStep.callTool('refresh'),
          AgentStep.callTool('clear'),
        ],
        (_) => const [AgentStep.say('Kept.')],
      ]);
      final thread = TandemThread(id: ThreadId('case-5411'));
      final first =
          (reopen ? openToClose(thread, agent) : open(agent, thread: thread))
            ..send('clear it');
      await pumpEventQueue();
      expect(_card(first).status, ApprovalStatus.pending);

      final TandemSession next;
      if (reopen) {
        first.dispose();
        shop.add('eggs');
        next = open(agent, thread: thread);
      } else {
        first.startOver();
        next = first;
      }
      next.send('keep it');
      await pumpEventQueue();

      expect(_card(next).status, ApprovalStatus.cancelled);
      expect(
        next.items.whereType<ChatNotice>().single.kind,
        ChatNoticeKind.startedOver,
      );
      expect(shop.refreshes, 1);
      expect(shop.items, contains('milk'));
      final [firstRun, secondRun] = agent.requests;
      expect(secondRun['threadId'], firstRun['threadId']);
      expect(secondRun['state'], isEmpty);
      expect(linesOf(secondRun), [
        'call-1 refresh {}',
        'call-2 clear {}',
        'call-1 -> null',
        'call-2 -> {"status":"cancelled"}',
        'user: keep it',
      ]);
    });
  }

  test('an empty thread id is refused', () {
    expect(() => ThreadId(''), throwsArgumentError);
  });

  test('a thread id equals an id the app gives with its value', () {
    final generated = TandemThread().id;
    final fromApp = ThreadId(generated.value);

    expect(generated, fromApp);
    expect(fromApp, generated);
    expect(generated.hashCode, fromApp.hashCode);
  });

  test('an app-id thread that started over and closed before the next message '
      'starts over only once on a changed screen', () async {
    shop.add('milk');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
      (_) => const [AgentStep.say('Kept.')],
    ]);
    final thread = TandemThread(id: ThreadId('case-5411'));
    final first = openToClose(thread, agent)..send('clear it');
    await pumpEventQueue();
    expect(_card(first).status, ApprovalStatus.pending);

    first
      ..startOver()
      ..dispose();
    shop.add('eggs');
    final next = open(agent, thread: thread)..send('keep it');
    await pumpEventQueue();

    expect(
      next.items.whereType<ChatNotice>().single.kind,
      ChatNoticeKind.startedOver,
    );
    expect(linesOf(agent.requests.last), [
      'call-1 clear {}',
      'call-1 -> {"status":"cancelled"}',
      'user: keep it',
    ]);
  });

  test('a throwing onEvent is reported; the next message works', () async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Done.')],
      (_) => const [AgentStep.say('Hi')],
    ]);
    final reported = collectReports();
    final session = open(
      agent,
      onEvent: (_) => throw StateError('listener failed'),
    )..send('add milk');
    await pumpEventQueue();

    expect(reported.single.exception, isStateError);
    expect(linesOf(agent.requests[1]).last, 'call-1 -> null');

    session.send('hello?');
    await pumpEventQueue();
    expect(summaryOf(session.items).last, ('agent', 'Hi', false));
  });

  test(
    'interleaved text grows each message in place until the run ends',
    () async {
      final connection = RawFirstRun(
        Stream.fromIterable([
          {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'Hel'},
          {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm2', 'delta': 'Next'},
          {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'lo'},
          {'type': 'RUN_FINISHED'},
          {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': ' late'},
        ]),
        ScriptedAgent([]),
      );
      final session = open(connection)..send('a');
      await pumpEventQueue();

      expect(summaryOf(session.items), [
        ('user', 'a'),
        ('agent', 'Hello', false),
        ('agent', 'Next', false),
      ]);
    },
  );

  test(
    'events after the end of a run change nothing while its calls run',
    () async {
      final serverReply = Completer<void>();
      shop.serverReply = serverReply.future;
      final first = StreamController<Map<String, Object?>>();
      final connection = RawFirstRun(
        first.stream,
        ScriptedAgent([
          (_) => const [AgentStep.say('Done.')],
        ]),
      );
      final session = open(connection)..send('a');
      first
        ..add(_toolStart('c1', 'refresh'))
        ..add({'type': 'RUN_FINISHED'});
      await pumpEventQueue();
      first
        ..add({
          'type': 'TEXT_MESSAGE_CONTENT',
          'messageId': 'm1',
          'delta': 'Late',
        })
        ..add({'type': 'RUN_FINISHED'});
      await pumpEventQueue();
      serverReply.complete();
      await pumpEventQueue();
      await first.close();

      expect(shop.refreshes, 1);
      expect(summaryOf(session.items), [
        ('user', 'a'),
        ('agent', 'Done.', false),
      ]);
    },
  );

  test(
    'a broken stream shows connection lost and starts a new thread',
    () async {
      final connection = RawFirstRun(
        Stream.value({'type': 'RUN_STARTED'}),
        ScriptedAgent([
          (_) => const [AgentStep.say('Back')],
        ]),
      );
      final session = open(connection)..send('a');
      await pumpEventQueue();
      expect(summaryOf(session.items), [
        ('user', 'a'),
        ChatNoticeKind.connectionLost,
      ]);
      expect(events, [isA<ConnectionLost>()]);

      session.send('b');
      await pumpEventQueue();
      final [first, second] = connection.requests;
      expect(second['threadId'], isNot(first['threadId']));
      expect(linesOf(second), ['user: b']);
      expect(summaryOf(session.items).last, ('agent', 'Back', false));
    },
  );

  test('a stream error is reported and shows connection lost', () async {
    const error = AgentHttpException(422, 'messages: field required');
    final reported = collectReports();
    final session = open(RawFirstRun(Stream.error(error), ScriptedAgent([])))
      ..send('a');
    await pumpEventQueue();

    expect(reported.single.exception, error);
    expect('${reported.single.exception}', contains('422'));
    expect(summaryOf(session.items).last, ChatNoticeKind.connectionLost);
  });

  test('an ambiguous chunk breaks the run: the response is cancelled, the '
      'error reported, and the next message starts a new thread', () async {
    var responseCancelled = false;
    // The server keeps the response open, so only the session can end it.
    final response = StreamController<Map<String, Object?>>(
      onCancel: () => responseCancelled = true,
    );
    addTearDown(response.close);
    response
      ..add({'type': 'RUN_STARTED'})
      ..add({
        'type': 'TEXT_MESSAGE_CHUNK',
        'messageId': 'm1',
        'subagentRunId': 's1',
        'delta': 'A',
      })
      ..add({
        'type': 'TEXT_MESSAGE_CHUNK',
        'messageId': 'm2',
        'subagentRunId': 's2',
        'delta': 'B',
      })
      ..add({'type': 'TEXT_MESSAGE_CHUNK', 'delta': 'C'});
    final connection = RawFirstRun(
      response.stream.transform(agUiRun(const {})),
      ScriptedAgent([
        (_) => const [AgentStep.say('Back')],
      ]),
    );
    final reported = collectReports();
    final session = open(connection)..send('a');
    await pumpEventQueue();

    expect(responseCancelled, isTrue);
    expect(reported.single.exception, isFormatException);
    expect(summaryOf(session.items), [
      ('user', 'a'),
      ('agent', 'A', false),
      ('agent', 'B', false),
      ChatNoticeKind.connectionLost,
    ]);

    session.send('b');
    await pumpEventQueue();
    final [first, second] = connection.requests;
    expect(second['threadId'], isNot(first['threadId']));
    expect(linesOf(second), ['user: b']);
    expect(summaryOf(session.items).last, ('agent', 'Back', false));
  });

  test('Approve runs the method once and continues', () async {
    final (session, agent) = await askToClear();
    final card = _card(session);
    expect(
      [card.tool, card.arguments, card.status, card.caller],
      ['clear', <String, Object?>{}, ApprovalStatus.pending, Caller.inAppAgent],
    );
    expect(shop.items, ['x']);

    session
      ..approve(card)
      ..approve(card);
    await pumpEventQueue();

    expect(shop.items, isEmpty);
    expect(agent.requests, hasLength(2));
    expect(linesOf(agent.requests[1]), [
      'user: clear it',
      'call-1 clear {}',
      'call-1 -> null',
    ]);
    expect(_card(session).status, ApprovalStatus.approved);
    final [AgentCall(:tool, :arguments, :result, :caller)] = agentCalls();
    expect((tool, result, caller), ('clear', null, Caller.inAppAgent));
    expect(arguments, isEmpty);
  });

  test('Reject answers rejected_by_user at once', () async {
    final (session, agent) = await askToClear();
    final card = _card(session);
    expect(session.isPending(card), isTrue);

    session.reject(card);
    await pumpEventQueue();
    expect(session.isPending(card), isFalse);

    expect(linesOf(agent.requests[1]), [
      'user: clear it',
      'call-1 clear {}',
      'call-1 -> {"status":"rejected_by_user"}',
    ]);
    expect(shop.items, ['x']);
    expect(_card(session).status, ApprovalStatus.rejected);
  });

  for (final reset in [true, false]) {
    test('a reused tool call ID needs its own approval after '
        '${reset ? 'startOver' : 'Reject'}', () async {
      shop.asksBeforeAdding = true;
      final agent = RawFirstRun(
        Stream.fromIterable([
          _toolStart('call-1', 'add'),
          _toolArgs('call-1', '{"item":"bread"}'),
          {'type': 'RUN_FINISHED'},
        ]),
        ScriptedAgent([
          (_) => const [
            AgentStep.callTool('add', {'item': 'milk'}),
          ],
          (_) => const [],
        ]),
      );
      final session = open(agent)..send('add bread');
      await pumpEventQueue();
      final old = _card(session);

      if (reset) {
        session
          ..startOver()
          ..send('add milk');
      } else {
        session.reject(old);
      }
      await pumpEventQueue();
      final fresh = session.items.whereType<ApprovalRequest>().last;
      expect(fresh.toolCallId, old.toolCallId);
      expect(fresh.key, isNot(old.key));
      expect(session.isPending(old), isFalse);
      expect(() => session.approve(old), throwsA(isA<ApprovalNotPending>()));
      expect(shop.items, isEmpty);
      expect(session.isPending(fresh), isTrue);

      session.approve(fresh.withStatus(.pending));
      await pumpEventQueue();
      expect(shop.items, ['milk']);
      final oldStatus = reset
          ? ApprovalStatus.cancelled
          : ApprovalStatus.rejected;
      expect(
        session.items.whereType<ApprovalRequest>().map((card) => card.status),
        [oldStatus, ApprovalStatus.approved],
      );
      expect(session.items.whereType<ApprovalRequest>().last.key, fresh.key);
      final ids = [
        for (final message in messagesOf(agent.requests.last)) message['id'],
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });
  }

  test('a request built by hand decides nothing', () async {
    final (session, _) = await askToClear();
    final card = _card(session);
    final byHand = ApprovalRequest(
      tool: card.tool,
      description: card.description,
      arguments: {},
    );

    expect(() => session.approve(byHand), throwsA(isA<ApprovalNotPending>()));
    await pumpEventQueue();

    expect(shop.items, ['x']);
    expect(session.isPending(card), isTrue);
  });

  test('a request built by hand keeps the nested arguments it got', () {
    final tags = ['cold'];
    final request = ApprovalRequest(
      tool: 'add',
      description: 'Adds items.',
      arguments: {
        'items': [
          {'name': 'milk', 'tags': tags},
        ],
      },
    );

    tags.add('fresh');

    expect(request.arguments, {
      'items': [
        {
          'name': 'milk',
          'tags': ['cold'],
        },
      ],
    });
  });

  test('each request built by hand has a key of its own', () {
    final first = ApprovalRequest(
      tool: 'add',
      description: 'Adds items.',
      arguments: {},
    );
    final second = ApprovalRequest(
      tool: 'add',
      description: 'Adds items.',
      arguments: {},
    );

    expect(first.key, isNot(second.key));
  });

  test('a pending card is AwaitingApproval', () async {
    final (session, _) = await askToClear();

    expect(
      session.status,
      isA<AwaitingApproval>().having(
        (status) => status.request,
        'request',
        _card(session),
      ),
    );
  });

  test('a change to .sees invalidates the card for good, also when undone '
      'later; the answer goes with the next message', () async {
    final (session, agent) = await askToClear();
    final card = _card(session);

    shop.add('y');
    await pumpEventQueue();
    shop.removeAt(1);
    await pumpEventQueue();
    expect(_card(session).status, ApprovalStatus.invalidated);
    expect(() => session.approve(card), throwsA(isA<ApprovalNotPending>()));
    await pumpEventQueue();
    expect(shop.items, ['x']);
    expect(agent.requests, hasLength(1));

    session.send('ok');
    await pumpEventQueue();
    expect(linesOf(agent.requests[1]), [
      'user: clear it',
      'call-1 clear {}',
      'call-1 -> ${ToolAnswer.invalidated.content}',
      'user: ok',
    ]);
  });

  test('Approve compares .sees itself, without a change signal', () async {
    final (session, agent) = await askToClear();

    shop.items.add('y');
    expect(
      () => session.approve(_card(session)),
      throwsA(isA<ApprovalNotPending>()),
    );
    await pumpEventQueue();

    expect(_card(session).status, ApprovalStatus.invalidated);
    expect(shop.items, ['x', 'y']);
    expect(agent.requests, hasLength(1));
  });

  test(
    'a .sees that cannot be read invalidates the card and is reported',
    () async {
      final reported = collectReports();
      final (session, _) = await askToClear();

      shop
        ..listThrows = true
        ..showTab(1);
      await pumpEventQueue();

      expect(_card(session).status, ApprovalStatus.invalidated);
      expect(reported.single.exception, isStateError);
    },
  );

  for (final (signal, addWhileThinking) in [
    ('with a change signal', () => shop.add('y')),
    ('without a change signal', () => shop.items.add('y')),
  ]) {
    test('a change to .sees $signal while the agent thinks invalidates its '
        'request before it shows', () async {
      shop.add('x');
      final gate = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(gate.future),
          const AgentStep.callTool('clear'),
        ],
        (_) => const [AgentStep.say('The list changed.')],
      ]);
      final session = open(agent)..send('clear it');
      await pumpEventQueue();

      addWhileThinking();
      gate.complete();
      await pumpEventQueue();

      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(
        linesOf(agent.requests[1]).last,
        'call-1 -> ${ToolAnswer.invalidated.content}',
      );
    });
  }

  test('a change outside .sees leaves the card pending', () async {
    final (session, _) = await askToClear();

    shop.showTab(1);
    await pumpEventQueue();

    expect(_card(session).status, ApprovalStatus.pending);
  });

  test(
    'tool changes invalidate approvals before change signals arrive',
    () async {
      final signals = Completer<void>();
      shop
        ..add('x')
        ..changesArrive = signals.future;
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('add', {'item': 'y'}),
          AgentStep.callTool('clear'),
        ],
        (_) => const [AgentStep.say('The list changed.')],
      ]);
      final session = open(agent)..send('go');
      await pumpEventQueue();

      expect(shop.items, ['x', 'y']);
      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(linesOf(agent.requests[1]), [
        'user: go',
        'call-1 add {"item":"y"}',
        'call-2 clear {}',
        'call-1 -> null',
        'call-2 -> ${ToolAnswer.invalidated.content}',
      ]);

      signals.complete();
      await pumpEventQueue();

      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(agent.requests, hasLength(2));
    },
  );

  test('a session disposed while an approved method runs sends, hears and '
      'reports nothing more', () async {
    final serverReply = Completer<void>();
    shop
      ..add('x')
      ..serverReply = serverReply.future;
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
    ]);
    final reported = collectReports();
    // Not open(), which would dispose it again at the end.
    final session = TandemSession(
      surface: shop,
      connection: agent,
      onEvent: events.add,
    )..send('clear it');
    await pumpEventQueue();

    session.approve(_card(session));
    await pumpEventQueue();
    session.dispose();
    serverReply.complete();
    await pumpEventQueue();

    expect(shop.items, isEmpty);
    expect(agent.requests, hasLength(1));
    expect(events, isEmpty);
    expect(reported, isEmpty);
  });

  test('a session disposed while a method without approval runs sends, '
      'hears and reports nothing more', () async {
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('refresh')],
    ]);
    final reported = collectReports();
    // Not open(), which would dispose it again at the end.
    final session = TandemSession(
      surface: shop,
      connection: agent,
      onEvent: events.add,
    )..send('refresh');
    await pumpEventQueue();

    session.dispose();
    serverReply.complete();
    await pumpEventQueue();

    expect(agent.requests, hasLength(1));
    expect(events, isEmpty);
    expect(reported, isEmpty);
  });

  test('Stop does nothing while an approved method runs, and its answer goes '
      'to the agent at once', () async {
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final (session, agent) = await askToClear();

    session
      ..approve(_card(session))
      ..stop();
    expect(
      session.status,
      isA<Calling>()
          .having((status) => status.tool, 'tool', 'clear')
          .having((status) => status.approved, 'approved', isTrue),
    );
    expect(events.whereType<RunStopped>(), isEmpty);
    serverReply.complete();
    await pumpEventQueue();

    expect(shop.items, isEmpty);
    expect(linesOf(agent.requests[1]), [
      'user: clear it',
      'call-1 clear {}',
      'call-1 -> null',
    ]);
    expect(summaryOf(session.items), [
      ('user', 'clear it'),
      ('clear', ApprovalStatus.approved),
      ('agent', 'Cleared.', false),
    ]);
  });

  test('a message while a card is open cancels it first', () async {
    final (session, agent) = await askToClear();

    session.send('wait');
    await pumpEventQueue();

    expect(_card(session).status, ApprovalStatus.cancelled);
    expect(linesOf(agent.requests[1]), [
      'user: clear it',
      'call-1 clear {}',
      'call-1 -> {"status":"cancelled"}',
      'user: wait',
    ]);
  });

  test('the messages sent during a run go after the answers of its calls, in '
      'the same run', () async {
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        AgentStep.waitFor(gate.future),
        const AgentStep.callTool('add', {'item': 'bread'}),
      ],
      (_) => const [AgentStep.say('Removed it.')],
    ]);
    final session = open(agent)..send('add bread');
    await pumpEventQueue();
    session
      ..send('no bread after all')
      ..send('and no milk');
    gate.complete();
    await pumpEventQueue();

    expect(agent.requests, hasLength(2));
    expect(linesOf(agent.requests[1]), [
      'user: add bread',
      'call-1 add {"item":"bread"}',
      'call-1 -> null',
      'user: no bread after all\n\nand no milk',
    ]);
  });

  test('every run gives the agent the latest five notes, new until a run '
      'took them, and the chat shows none', () async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Hi again.')],
    ]);
    final session = open(agent);
    for (var i = 1; i <= 6; i++) {
      session.note('note $i');
    }
    session.send('hi');
    await pumpEventQueue();
    session
      ..note('note 7')
      ..send('again');
    await pumpEventQueue();

    expect(
      [for (final request in agent.requests) appNotesOf(request)],
      [
        {
          'new': [
            for (var i = 2; i <= 6; i++) {'note': 'note $i'},
          ],
        },
        {
          'new': [
            {'note': 'note 7'},
          ],
          'earlier': [
            for (var i = 3; i <= 6; i++) {'note': 'note $i'},
          ],
        },
      ],
    );
    expect(summaryOf(session.items), [
      ('user', 'hi'),
      ('agent', 'Hi.', false),
      ('user', 'again'),
      ('agent', 'Hi again.', false),
    ]);
  });

  test('the notes stay new when the run that offered them fails', () async {
    collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.fail('Out of tokens.')],
      (_) => const [AgentStep.say('Hi.')],
    ]);
    final session = open(agent)
      ..note('The user opened the cart.')
      ..send('hi');
    await pumpEventQueue();
    session.send('hi again');
    await pumpEventQueue();

    expect(appNotesOf(agent.requests[1]), {
      'new': [
        {'note': 'The user opened the cart.'},
      ],
    });
  });

  test('a run the backend cancels took the notes it offered', () async {
    final agent = RawFirstRun(
      Stream.fromIterable([
        {
          'type': 'RUN_FINISHED',
          'outcome': {'type': 'cancelled'},
        },
      ]),
      ScriptedAgent([
        (_) => const [AgentStep.say('Hi.')],
      ]),
    );
    final session = open(agent)
      ..note('The user opened the cart.')
      ..send('hi');
    await pumpEventQueue();
    session.send('hi again');
    await pumpEventQueue();

    expect(appNotesOf(agent.requests[1]), {
      'earlier': [
        {'note': 'The user opened the cart.'},
      ],
    });
  });

  test('notes written while a run is open stay new when the notes it offered '
      'drop out', () async {
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(gate.future), const AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Again.')],
    ]);
    final session = open(agent)
      ..note('note 1')
      ..send('hi');
    await pumpEventQueue();
    for (var i = 2; i <= 7; i++) {
      session.note('note $i');
    }
    gate.complete();
    await pumpEventQueue();
    session.send('again');
    await pumpEventQueue();

    expect(appNotesOf(agent.requests[1]), {
      'new': [
        for (var i = 3; i <= 7; i++) {'note': 'note $i'},
      ],
    });
  });

  test('the text of a run that failed goes back in the history', () async {
    collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Half an'), AgentStep.fail('Out of tokens.')],
      (_) => const [AgentStep.say('Hi.')],
    ]);
    final session = open(agent)..send('hi');
    await pumpEventQueue();
    session.send('again');
    await pumpEventQueue();

    expect(linesOf(agent.requests[1]), [
      'user: hi',
      'assistant: Half an',
      'user: again',
    ]);
  });

  test('the agent state follows its snapshots and deltas as they come, also '
      'after a Stop, and the next run sends it back', () async {
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        const AgentStep.stateSnapshot({
          'steps': ['Find the customer'],
        }),
        AgentStep.waitFor(gate.future),
        const AgentStep.stateDelta([
          {'op': 'add', 'path': '/steps/-', 'value': 'Read the history'},
        ]),
      ],
      (_) => const [AgentStep.say('Done.')],
    ]);
    final session = open(agent)..send('find Acme');
    await pumpEventQueue();
    expect(session.agentState, {
      'steps': ['Find the customer'],
    });

    session.stop();
    gate.complete();
    await pumpEventQueue();
    expect(session.agentState, {
      'steps': ['Find the customer', 'Read the history'],
    });

    session.send('go on');
    await pumpEventQueue();
    expect(agent.requests.first['state'], isEmpty);
    expect(agent.requests.last['state'], session.agentState);
  });

  test('a delta that does not apply is reported and keeps the state, and the '
      'deltas after it wait for a snapshot', () async {
    final reported = collectReports();
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        const AgentStep.stateSnapshot({'step': 1}),
        const AgentStep.stateDelta([
          {'op': 'replace', 'path': '/step', 'value': 2},
          {'op': 'replace', 'path': '/missing', 'value': 2},
        ]),
        const AgentStep.stateDelta([
          {'op': 'replace', 'path': '/step', 'value': 3},
        ]),
        AgentStep.waitFor(gate.future),
        const AgentStep.stateSnapshot({'step': 4}),
        const AgentStep.stateDelta([
          {'op': 'replace', 'path': '/step', 'value': 5},
        ]),
        const AgentStep.say('Still here.'),
      ],
    ]);
    final session = open(agent)..send('go');
    await pumpEventQueue();
    expect(session.agentState, {'step': 1});
    expect(reported.single.exception, isFormatException);

    gate.complete();
    await pumpEventQueue();
    expect(session.agentState, {'step': 5});
    expect(summaryOf(session.items).last, ('agent', 'Still here.', false));
  });

  test('the deltas of the next run apply after a delta that did not', () async {
    collectReports();
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.stateSnapshot({'step': 1}),
        AgentStep.stateDelta([
          {'op': 'replace', 'path': '/missing', 'value': 2},
        ]),
        AgentStep.say('Hm.'),
      ],
      (_) => const [
        AgentStep.stateDelta([
          {'op': 'replace', 'path': '/step', 'value': 2},
        ]),
        AgentStep.say('Done.'),
      ],
    ]);
    final session = open(agent)..send('a');
    await pumpEventQueue();
    session.send('b');
    await pumpEventQueue();

    expect(session.agentState, {'step': 2});
  });

  test('agent state owns a stable immutable snapshot, including nested '
      'snapshot and patch values', () async {
    final step = <String, Object?>{'name': 'Read'};
    final steps = <Object?>[step];
    final plan = <String, Object?>{'steps': steps};
    final snapshot = <String, Object?>{'plan': plan};
    final tags = <Object?>['new'];
    final detail = <String, Object?>{'tags': tags};
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        AgentStep.stateSnapshot(snapshot),
        AgentStep.waitFor(gate.future),
        AgentStep.stateDelta([
          {'op': 'add', 'path': '/plan/detail', 'value': detail},
        ]),
      ],
      (_) => const [AgentStep.say('Done.')],
    ]);
    final session = open(agent)..send('go');
    await pumpEventQueue();
    final initial = session.agentState;
    expect(session.agentState, same(initial));
    final {'plan': frozenPlan as Map<String, Object?>} = initial;
    final {'steps': frozenSteps as List<Object?>} = frozenPlan;
    final [frozenStep as Map<String, Object?>] = frozenSteps;
    expect(() => initial['other'] = true, throwsUnsupportedError);
    expect(() => frozenPlan['other'] = true, throwsUnsupportedError);
    expect(() => frozenStep['name'] = 'UI', throwsUnsupportedError);
    expect(frozenSteps.clear, throwsUnsupportedError);

    step['name'] = 'Adapter';
    steps.clear();
    plan.clear();
    snapshot.clear();
    expect(initial, {
      'plan': {
        'steps': [
          {'name': 'Read'},
        ],
      },
    });

    gate.complete();
    await pumpEventQueue();
    final patched = session.agentState;
    expect(patched, isNot(same(initial)));
    expect(session.agentState, same(patched));
    final {'plan': patchedPlan as Map<String, Object?>} = patched;
    final {'detail': frozenDetail as Map<String, Object?>} = patchedPlan;
    final {'tags': frozenTags as List<Object?>} = frozenDetail;
    expect(frozenDetail.clear, throwsUnsupportedError);
    expect(() => frozenTags.add('UI'), throwsUnsupportedError);
    tags.add('Adapter');
    detail.clear();
    expect(frozenTags, ['new']);
    expect(frozenPlan.containsKey('detail'), isFalse);

    session.send('again');
    await pumpEventQueue();
    expect(agent.requests.last['state'], {
      'plan': {
        'steps': [
          {'name': 'Read'},
        ],
        'detail': {
          'tags': ['new'],
        },
      },
    });
  });

  test('a snapshot that is not an object is reported and keeps the state, '
      'and the deltas after it wait for a snapshot', () async {
    final reported = collectReports();
    final connection = RawFirstRun(
      Stream.fromIterable([
        {
          'type': 'STATE_SNAPSHOT',
          'snapshot': ['steps'],
        },
        {
          'type': 'STATE_DELTA',
          'delta': [
            {'op': 'add', 'path': '/step', 'value': 1},
          ],
        },
        {'type': 'RUN_FINISHED'},
      ]),
      ScriptedAgent([]),
    );
    final session = open(connection)..send('go');
    await pumpEventQueue();

    expect(session.agentState, isEmpty);
    expect(reported.single.exception, isFormatException);
  });

  test('a new thread starts with an empty agent state', () async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.stateSnapshot({'step': 1}),
      ],
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    final session = open(agent)..send('a');
    await pumpEventQueue();

    session.startOver();
    expect(session.agentState, isEmpty);
    session.send('b');
    await pumpEventQueue();
    expect(agent.requests.last['state'], isEmpty);
  });

  test('the next session goes on with the thread: its chat, its history and '
      'the agent state', () async {
    final thread = TandemThread();
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.stateSnapshot({'step': 1}),
        AgentStep.say('Hi.'),
      ],
      (_) => const [AgentStep.say('Again.')],
    ]);
    final first = openToClose(thread, agent)..send('a');
    await pumpEventQueue();
    first.dispose();
    final next = open(agent, thread: thread);
    expect(summaryOf(next.items), [('user', 'a'), ('agent', 'Hi.', false)]);

    next.send('b');
    await pumpEventQueue();
    expect(agent.requests[1]['threadId'], agent.requests[0]['threadId']);
    expect(linesOf(agent.requests[1]), [
      'user: a',
      'assistant: Hi.',
      'user: b',
    ]);
    expect(agent.requests[1]['state'], {'step': 1});
  });

  test('a thread whose screen changed while no session had it starts over '
      'before the next message', () async {
    final (thread, agent) = await closeAfterFirstReply();
    shop.add('milk');

    final next = open(agent, thread: thread)..send('b');
    await pumpEventQueue();
    expect(agent.requests[1]['threadId'], isNot(agent.requests[0]['threadId']));
    expect(linesOf(agent.requests[1]), ['user: b']);
    expect(summaryOf(next.items), [
      ('user', 'a'),
      ('agent', 'Hi.', false),
      ChatNoticeKind.startedOver,
      ('user', 'b'),
      ('agent', 'Fresh.', false),
    ]);
  });

  test('a session that sent nothing leaves the thread what the screen showed '
      'the last session that sent', () async {
    final (thread, agent) = await closeAfterFirstReply();
    shop.add('milk');
    openToClose(thread, agent).dispose();

    final next = open(agent, thread: thread)..send('b');
    await pumpEventQueue();
    expect(agent.requests[1]['threadId'], isNot(agent.requests[0]['threadId']));
    expect(summaryOf(next.items).whereType<ChatNoticeKind>(), [
      ChatNoticeKind.startedOver,
    ]);
  });

  test('startOver forgets what the screen showed when the last session let '
      'the thread go', () async {
    final (thread, agent) = await closeAfterFirstReply();
    final next = open(agent, thread: thread)..startOver();
    shop.add('milk');
    next.send('b');
    await pumpEventQueue();

    expect(summaryOf(next.items).whereType<ChatNoticeKind>(), [
      ChatNoticeKind.startedOver,
    ]);
  });

  test('a session closed while a run is open leaves its thread to a new '
      'AG-UI thread', () async {
    final thread = TandemThread();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(Completer<void>().future)],
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    final first = openToClose(thread, agent)..send('a');
    await pumpEventQueue();
    first.dispose();

    open(agent, thread: thread).send('b');
    await pumpEventQueue();
    expect(agent.requests[1]['threadId'], isNot(agent.requests[0]['threadId']));
    expect(linesOf(agent.requests[1]), ['user: b']);
  });

  test('a session closed while a request waits leaves its cancelled answer '
      'to the next one', () async {
    final thread = TandemThread();
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
      (_) => const [AgentStep.say('Kept.')],
    ]);
    final first = openToClose(thread, agent)..send('clear it');
    await pumpEventQueue();
    first.dispose();

    final next = open(agent, thread: thread)..send('keep it');
    await pumpEventQueue();
    expect(_card(next).status, ApprovalStatus.cancelled);
    expect(linesOf(agent.requests[1]), [
      'user: clear it',
      'call-1 clear {}',
      'call-1 -> {"status":"cancelled"}',
      'user: keep it',
    ]);
  });

  test('a newer session takes the thread, and the older one lets it go as '
      'if it closed', () async {
    final thread = TandemThread();
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
      (_) => const [AgentStep.say('Kept.')],
    ]);
    final first = openToClose(thread, agent)..send('clear it');
    await pumpEventQueue();

    final next = open(agent, thread: thread);
    first
      ..send('ignored')
      ..dispose();
    next.send('keep it');
    await pumpEventQueue();
    expect(_card(next).status, ApprovalStatus.cancelled);
    expect(linesOf(agent.requests.last).last, 'user: keep it');
    expect(agent.requests, hasLength(2));
  });

  test('a retired session refuses calls before reading the surface or '
      'asking for approval, while the new owner accepts them', () async {
    final thread = TandemThread();
    final agent = ScriptedAgent([]);
    final first = open(agent, thread: thread);
    var retirements = 0;
    first.addListener(() => retirements++);
    final next = open(agent, thread: thread);

    expect(first.isActive, isFalse);
    expect(next.isActive, isTrue);
    await pumpEventQueue();
    expect(retirements, 1);
    shop.listThrows = true;
    for (final method in ['add', 'share']) {
      final answer = await first.callFor(.codingAgent, method, {
        'item': 'milk',
      });
      expect(answer.json, {
        'status': 'refused',
        'reason': 'This session no longer owns its thread.',
      });
    }
    expect(first.items.whereType<ApprovalRequest>(), isEmpty);
    shop.listThrows = false;
    await next.callFor(.codingAgent, 'add', {'item': 'milk'});
    expect(shop.items, ['milk']);
  });

  test('an approved method started before retirement finishes without '
      'using the new owner', () async {
    final gate = Completer<void>();
    shop
      ..add('milk')
      ..serverReply = gate.future;
    final thread = TandemThread();
    final agent = ScriptedAgent([]);
    final first = open(agent, thread: thread);
    final answer = first.callFor(.codingAgent, 'clear', {});
    first.approve(_card(first));
    final next = open(agent, thread: thread);

    gate.complete();
    expect((await answer).status, ToolStatus.returned);
    await pumpEventQueue();
    expect(shop.items, isEmpty);
    expect(next.status, isA<Idle>());
    expect(events, isEmpty);
    expect(agent.requests, isEmpty);
  });

  test('a session closed while an approved method of a coding agent runs '
      'keeps the thread', () async {
    final gate = Completer<void>();
    shop.serverReply = gate.future;
    final thread = TandemThread();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Again.')],
    ]);
    final first = openToClose(thread, agent)..send('a');
    await pumpEventQueue();
    final answer = first.callFor(.codingAgent, 'share', {});
    first
      ..approve(_card(first))
      ..dispose();
    gate.complete();
    expect((await answer).status, ToolStatus.returned);

    final next = open(agent, thread: thread)..send('b');
    await pumpEventQueue();
    expect(agent.requests[1]['threadId'], agent.requests[0]['threadId']);
    expect(linesOf(agent.requests[1]), [
      'user: a',
      'assistant: Hi.',
      'user: b',
    ]);
    expect(summaryOf(next.items).whereType<ChatNoticeKind>(), isEmpty);
  });

  test('a change on the screen before it closed keeps the thread', () async {
    final thread = TandemThread();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Again.')],
    ]);
    final first = openToClose(thread, agent)..send('a');
    await pumpEventQueue();
    shop.add('milk');
    first.dispose();

    open(agent, thread: thread).send('b');
    await pumpEventQueue();
    expect(agent.requests[1]['threadId'], agent.requests[0]['threadId']);
  });

  test('a broken run keeps the app ID and clears state and answers '
      'that may have reached the backend', () async {
    collectReports();
    shop.add('milk');
    final response = Completer<void>();
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.stateSnapshot({'step': 1}),
        AgentStep.callTool('clear'),
      ],
      (_) => [AgentStep.waitFor(response.future)],
      (_) => const [AgentStep.say('Back')],
    ]);
    final session = open(agent, thread: TandemThread(id: ThreadId('case-5411')))
      ..send('a');
    await pumpEventQueue();
    session.send('b');
    await pumpEventQueue();

    response.completeError(StateError('Connection lost.'));
    await pumpEventQueue();
    session.send('c');
    await pumpEventQueue();

    expect(agent.requests.map((run) => run['threadId']), [
      'case-5411',
      'case-5411',
      'case-5411',
    ]);
    expect(linesOf(agent.requests[1]), [
      'user: a',
      'call-1 clear {}',
      'call-1 -> {"status":"cancelled"}',
      'user: b',
    ]);
    expect(linesOf(agent.requests[2]), ['user: c']);
    expect(agent.requests[2]['state'], isEmpty);
  });

  test('wake starts a run with a message from the app, which waits while a '
      'request waits and goes with the run after the decision', () async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Nothing new.')],
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Shared twice.')],
    ]);
    final session = open(agent)..wake();
    await pumpEventQueue();
    expect(linesOf(agent.requests.single).single, startsWith('user: The app'));
    expect(
      session.items.first,
      isA<UserMessage>().having(
        (message) => message.fromApp,
        'fromApp',
        isTrue,
      ),
    );

    session.send('share it twice');
    await pumpEventQueue();
    session.wake();
    await pumpEventQueue();
    session.approve(_card(session));
    await pumpEventQueue();
    expect(summaryOf(session.items).last, ('share', ApprovalStatus.pending));
    expect(agent.requests, hasLength(2));

    session.approve(session.items.whereType<ApprovalRequest>().last);
    await pumpEventQueue();
    expect(linesOf(agent.requests[2]).skip(3), [
      'call-1 share {}',
      'call-2 share {}',
      'call-1 -> null',
      'call-2 -> null',
      startsWith('user: The app'),
    ]);
  });

  test("after Stop, the app's message waits for the user's next one", () async {
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(gate.future), const AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Hi again.')],
    ]);
    final session = open(agent)..send('hi');
    await pumpEventQueue();
    session
      ..wake()
      ..stop();
    gate.complete();
    await pumpEventQueue();
    expect(agent.requests, hasLength(1));

    session.send('again');
    await pumpEventQueue();
    expect(
      linesOf(agent.requests[1]).last,
      allOf(startsWith('user: The app'), endsWith('\n\nagain')),
    );
  });

  test("the app's message waits for a method that the approval callback "
      'approved at once', () async {
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        AgentStep.waitFor(gate.future),
        const AgentStep.callTool('share'),
      ],
      (_) => const [AgentStep.say('Shared.')],
    ]);
    late final TandemSession session;
    session = TandemSession(
      surface: shop,
      connection: agent,
      onEvent: events.add,
      onApprovalRequest: (request) async => session.approve(request),
    )..send('share it');
    addTearDown(session.dispose);
    await pumpEventQueue();
    session.wake();
    gate.complete();
    await pumpEventQueue();

    expect(session.status, const Calling('share', approved: true));
    expect(agent.requests, hasLength(1));

    serverReply.complete();
    await pumpEventQueue();
    expect(linesOf(agent.requests[1]).skip(1), [
      'call-1 share {}',
      'call-1 -> null',
      startsWith('user: The app'),
    ]);
    expect(summaryOf(session.items).last, ('agent', 'Shared.', false));
  });

  test('a call with arguments that are not an object is refused without a '
      'card or a report', () async {
    shop.add('x');
    final connection = RawFirstRun(
      Stream.fromIterable([
        {'type': 'TOOL_CALL_START', 'toolCallId': 'c1', 'toolCallName': 'add'},
        _toolArgs('c1', '{"item":'),
        _toolStart('c2', 'clear'),
        _toolArgs('c2', '[]'),
        {'type': 'RUN_FINISHED'},
      ]),
      ScriptedAgent([
        (_) => const [AgentStep.say('Sorry.')],
      ]),
    );
    final reported = collectReports();
    final session = open(connection)..send('clear it');
    await pumpEventQueue();

    expect(session.items.whereType<ApprovalRequest>(), isEmpty);
    expect(shop.items, ['x']);
    expect(reported, isEmpty);
    final [..., {'content': first as String}, {'content': second as String}] =
        messagesOf(connection.requests[1]);
    for (final answer in [first, second]) {
      expect(jsonDecode(answer), {'status': 'refused', 'reason': isNotEmpty});
    }
  });

  test('the next request shows once the previous one is approved and its '
      'method returned', () async {
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Shared twice.')],
    ]);
    final session = open(agent)..send('share it twice');
    await pumpEventQueue();

    session.approve(_card(session));
    await pumpEventQueue();
    expect(summaryOf(session.items).last, ('share', ApprovalStatus.approved));

    serverReply.complete();
    await pumpEventQueue();
    expect(summaryOf(session.items).skip(1), [
      ('share', ApprovalStatus.approved),
      ('share', ApprovalStatus.pending),
    ]);
  });

  test('an approved method that changes .sees invalidates the rest', () async {
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear'), AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Cleared.')],
    ]);
    final session = open(agent)..send('clear and share');
    await pumpEventQueue();

    session.approve(_card(session));
    await pumpEventQueue();

    expect(_card(session).tool, 'clear');
    expect(linesOf(agent.requests[1]).skip(3), [
      'call-1 -> null',
      'call-2 -> ${ToolAnswer.invalidated.content}',
    ]);
  });

  test(
    'an approved request is no longer pending and cannot be rejected',
    () async {
      final serverReply = Completer<void>();
      shop.serverReply = serverReply.future;
      final (session, _) = await askToClear();
      final card = _card(session);

      session.approve(card);

      expect(session.isPending(card), isFalse);
      expect(() => session.reject(card), throwsA(isA<ApprovalNotPending>()));
      serverReply.complete();
      await pumpEventQueue();
    },
  );

  test('a list that throws after an approved method leaves the session '
      'usable', () async {
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final reported = collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
    ]);
    final session = open(agent)..send('share it twice');
    await pumpEventQueue();
    session.approve(_card(session));
    await pumpEventQueue();

    shop.listThrows = true;
    serverReply.complete();
    await pumpEventQueue();

    expect(session.status, isA<Idle>());
    expect(
      reported.map((details) => details.exception),
      everyElement(isStateError),
    );
  });

  test('the same call of a coding agent joins the waiting request in any key '
      'order, and the same tool with other arguments is refused', () async {
    final mailbox = _Mailbox();
    final session = TandemSession(
      surface: mailbox,
      connection: ScriptedAgent(const []),
    );
    addTearDown(session.dispose);

    final first = session.callFor(.codingAgent, 'post', {
      'to': 'Ana',
      'text': 'Hi.',
    });
    final again = session.callFor(.codingAgent, 'post', {
      'text': 'Hi.',
      'to': 'Ana',
    });
    final other = await session.callFor(.codingAgent, 'post', {
      'to': 'Bea',
      'text': 'Hi.',
    });
    session.approve(_card(session));

    expect((await first).status, ToolStatus.returned);
    expect((await again).status, ToolStatus.returned);
    expect(other.status, ToolStatus.refused);
    expect(mailbox.sent, ['Ana: Hi.']);
  });

  test("a message cancels the request that shows, and another caller's "
      'request that waits shows after the run', () async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Not shared.')],
    ]);
    final session = open(agent)..send('share it');
    await pumpEventQueue();
    final coding = session.callFor(.codingAgent, 'share', {});

    session.send('wait');
    await pumpEventQueue();
    session.approve(session.items.whereType<ApprovalRequest>().last);

    expect((await coding).status, ToolStatus.returned);
    expect(
      [
        for (final request in session.items.whereType<ApprovalRequest>())
          (request.caller, request.status),
      ],
      [
        (Caller.inAppAgent, ApprovalStatus.cancelled),
        (Caller.codingAgent, ApprovalStatus.approved),
      ],
    );
  });

  test('three refused views in a row, counted since the last that showed, '
      'withhold the tool until the next message', () async {
    const fits = AgentStep.callTool(ViewTool.name, {'fits': true});
    const breaks = AgentStep.callTool(ViewTool.name, {'fits': false});
    final agent = ScriptedAgent([
      (_) => const [breaks],
      (_) => const [fits, breaks],
      (_) => const [breaks],
      (_) => const [breaks],
      (_) => const [AgentStep.say('In text, then.')],
      (_) => const [AgentStep.say('Hi.')],
    ]);
    final session = open(agent)
      ..attach(_Canvas())
      ..send('draw');
    await pumpEventQueue();
    bool offersView(Map<String, Object?> body) {
      final {'tools': tools as List<Object?>} = body;
      return tools.any((tool) => tool is Map && tool['name'] == ViewTool.name);
    }

    expect(agent.requests.map(offersView), [true, true, true, true, false]);
    expect(
      linesOf(agent.requests[4]).last,
      contains('Answer the user in text.'),
    );

    session.send('again');
    await pumpEventQueue();
    expect(offersView(agent.requests[5]), isTrue);
  });

  test('a decision after dispose throws and sends nothing', () async {
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
    ]);
    // Not open(), which would dispose it again at the end.
    final session = TandemSession(surface: shop, connection: agent)
      ..send('clear it');
    await pumpEventQueue();
    final card = _card(session);

    session.dispose();

    expect(session.isPending(card), isFalse);
    expect(() => session.approve(card), throwsA(isA<ApprovalNotPending>()));
    expect(() => session.reject(card), throwsA(isA<ApprovalNotPending>()));
    session.send('still there?');
    await pumpEventQueue();
    expect(shop.items, ['x']);
    expect(agent.requests, hasLength(1));
  });

  test('a rejection cancels the rest of the turn', () async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Not shared.')],
    ]);
    final session = open(agent)..send('share it twice');
    await pumpEventQueue();

    session.reject(_card(session));
    await pumpEventQueue();

    expect(_card(session).status, ApprovalStatus.rejected);
    expect(linesOf(agent.requests[1]).skip(3), [
      'call-1 -> {"status":"rejected_by_user"}',
      'call-2 -> {"status":"cancelled"}',
    ]);
  });

  test('several calls in one turn are answered in one run', () async {
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('refresh'), AgentStep.callTool('clear')],
      (_) => const [AgentStep.say('Done.')],
    ]);
    final session = open(agent)..send('go');
    await pumpEventQueue();
    expect(_card(session).status, ApprovalStatus.pending);
    expect(agent.requests, hasLength(1));

    session.approve(_card(session));
    await pumpEventQueue();

    expect(agent.requests, hasLength(2));
    expect(linesOf(agent.requests[1]), [
      'user: go',
      'call-1 refresh {}',
      'call-2 clear {}',
      'call-1 -> null',
      'call-2 -> null',
    ]);
  });

  test(
    'a change during an async tool invalidates approval even when undone',
    () async {
      shop.add('x');
      final gate = Completer<void>();
      shop.serverReply = gate.future;
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('refresh'),
          AgentStep.callTool('clear'),
        ],
        (_) => const [AgentStep.say('Please confirm the new plan.')],
      ]);
      final session = open(agent)..send('refresh and clear');
      await pumpEventQueue();

      shop.add('y');
      await pumpEventQueue();
      shop.removeAt(1);
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();

      expect(shop.items, ['x']);
      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(
        linesOf(agent.requests[1]).last,
        'call-2 -> ${ToolAnswer.invalidated.content}',
      );
    },
  );

  test('Stop from a Calling listener prevents invocation', () async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'x'}),
      ],
    ]);
    final session = open(agent);
    session.addListener(() {
      if (session.status is Calling) {
        session.stop();
      }
    });
    session.send('add x');
    await pumpEventQueue();

    expect(shop.items, isEmpty);
    expect(agent.requests, hasLength(1));
    expect(session.status, isA<Idle>());
    expect(events, [isA<RunStopped>()]);
  });

  test('a session that lets its thread go from a Calling listener runs no '
      'method', () async {
    final thread = TandemThread();
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'x'}),
      ],
    ]);
    final session = open(agent, thread: thread);
    session.addListener(() {
      if (session.status is Calling && session.isActive) {
        open(agent, thread: thread);
      }
    });
    session.send('add x');
    await pumpEventQueue();

    expect(session.isActive, isFalse);
    expect(shop.items, isEmpty);
  });

  test(
    'an unsupported outcome discards calls and preserves queued user input',
    () async {
      var responseCancelled = false;
      final stream = StreamController<Map<String, Object?>>(
        onCancel: () => responseCancelled = true,
      );
      final connection = RawFirstRun(
        stream.stream,
        ScriptedAgent([
          (_) => const [AgentStep.say('New conversation.')],
        ]),
      );
      final reported = collectReports();
      final session = open(connection)..send('go');
      stream
        ..add(_toolStart('c1', 'add'))
        ..add(_toolArgs('c1', '{"item":"x"}'))
        ..add(_toolStart('c2', 'share'));
      await pumpEventQueue();
      session
        ..send('queued')
        ..send('also queued');
      stream.add({
        'type': 'RUN_FINISHED',
        'outcome': {'type': 'interrupt'},
      });
      await pumpEventQueue();
      expect(responseCancelled, isTrue);
      await stream.close();

      expect(shop.items, isEmpty);
      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(connection.requests, hasLength(1));
      expect(session.status, isA<Idle>());
      expect(summaryOf(session.items).last, ChatNoticeKind.runFailed);
      expect(reported.single.exception, isA<AgentRunException>());
      expect(events, [isA<RunFailed>()]);

      session.send('next');
      await pumpEventQueue();

      final [first, second] = connection.requests;
      expect(second['threadId'], isNot(first['threadId']));
      expect(linesOf(second), ['user: queued\n\nalso queued\n\nnext']);
    },
  );

  test(
    'a cancelled outcome stops without executing calls or asking for approval',
    () async {
      final connection = RawFirstRun(
        Stream.fromIterable([
          _toolStart('c1', 'add'),
          _toolArgs('c1', '{"item":"x"}'),
          _toolStart('c2', 'share'),
          {
            'type': 'RUN_FINISHED',
            'outcome': {'type': 'cancelled'},
          },
        ]),
        ScriptedAgent([
          (_) => const [AgentStep.say('OK.')],
        ]),
      );
      final session = open(connection)..send('go');
      await pumpEventQueue();

      expect(shop.items, isEmpty);
      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(connection.requests, hasLength(1));
      expect(session.status, isA<Idle>());
      expect(summaryOf(session.items).last, ChatNoticeKind.stopped);
      expect(events, [isA<RunStopped>()]);

      session.send('next');
      await pumpEventQueue();

      expect(linesOf(connection.requests[1]), [
        'user: go',
        'c1 add {"item":"x"}',
        'c2 share {}',
        'c1 -> {"status":"cancelled"}',
        'c2 -> {"status":"cancelled"}',
        'user: next',
      ]);
    },
  );

  test(
    'repeated tool starts preserve arguments and their first history message',
    () async {
      final reported = collectReports();
      final connection = RawFirstRun(
        Stream.fromIterable([
          _toolStart('c1', 'add', parent: 'm1'),
          _toolArgs('c1', '{"item":'),
          _toolStart('c1', 'add', parent: 'ignored'),
          _toolArgs('c1', '"x"}'),
          _toolStart('b1', 'lookup', parent: 'm2'),
          _toolArgs('b1', '{"q":'),
          _toolStart('b1', 'lookup', parent: 'ignored'),
          _toolArgs('b1', '"x"}'),
          {
            'type': 'TOOL_CALL_RESULT',
            'toolCallId': 'b1',
            'messageId': 'r1',
            'content': '[]',
          },
          {'type': 'RUN_FINISHED'},
        ]),
        ScriptedAgent([
          (_) => const [AgentStep.say('Done.')],
        ]),
      );
      open(connection).send('go');
      await pumpEventQueue();
      expect(shop.items, ['x']);
      expect(reported, isEmpty);
      final history = messagesOf(connection.requests[1]).skip(1);
      expect(linesOf(connection.requests[1]).skip(1), [
        'c1 add {"item":"x"}',
        'b1 lookup {"q":"x"}',
        'b1 -> []',
        'c1 -> null',
      ]);
      expect([for (final message in history) message['id']].take(3), [
        'm1',
        'm2',
        'r1',
      ]);
    },
  );

  test('a tool id cannot change name across app and backend calls', () async {
    final reported = collectReports();
    for (final (first, second) in [
      ('lookup', 'add'),
      ('add', 'lookup'),
      ('lookup', 'search'),
    ]) {
      final connection = RawFirstRun(
        Stream.fromIterable([
          _toolStart('before', 'add'),
          _toolArgs('before', '{"item":"before"}'),
          _toolStart('c1', first),
          _toolArgs('c1', '{"item":"y"}'),
          _toolStart('c1', second),
          {'type': 'RUN_FINISHED'},
        ]),
        ScriptedAgent([]),
      );
      final session = open(connection)..send('conflicting');
      await pumpEventQueue();
      expect(shop.items, isEmpty, reason: '$first → $second');
      expect(connection.requests, hasLength(1));
      expect(session.items.whereType<ApprovalRequest>(), isEmpty);
      expect(summaryOf(session.items).last, ChatNoticeKind.runFailed);
    }
    expect(reported, hasLength(3));
    expect(
      reported.map((report) => report.exception),
      everyElement(isFormatException),
    );
  });

  test("a converter's bug fails the call, also before it asks for approval, "
      'and only the report gets it', () async {
    final reported = collectReports();
    final session = TandemSession(
      surface: _Palette(),
      connection: ScriptedAgent([]),
    );
    addTearDown(session.dispose);

    for (final tool in ['paint', 'order']) {
      expect(
        await session.callFor(.codingAgent, tool, {'color': 'red'}),
        ToolAnswer.failed,
      );
    }
    expect(reported.map((report) => report.exception), [
      isStateError,
      isStateError,
    ]);
    expect(session.items, isEmpty);
  });

  test('the note of an action of a view names the object the user picked, '
      'also once the screen no longer lists it', () async {
    final nursery = _Nursery();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Opened.')],
    ]);
    final session = TandemSession(surface: nursery, connection: agent);
    addTearDown(session.dispose);

    await session.callFor(.view, 'open', {
      'grower': {'path': '/growers/0'},
    }, seen: AgentListing.of(nursery));
    session.send('What did I open?');
    await pumpEventQueue();

    final request = AgentRequest(agent.requests.single);
    expect(request.context('growers'), [
      {'name': 'Bea'},
    ]);
    expect(request.newNotes, [
      {
        'pressed': 'open',
        'arguments': {
          'grower': {'name': 'Ana'},
        },
        'status': 'returned',
        'result': null,
      },
    ]);
  });
}

ApprovalRequest _card(TandemSession session) =>
    session.items.whereType<ApprovalRequest>().single;

/// A screen whose growers leave the list once opened.
final class _Nursery() implements AgentSurface {
  static final AgentType<_Grower> _grower = .object(
    id: 'test#Grower',
    fields: (field) => [field('name', (value) => value.name).as(.string)],
    build: (values) => .new(values('name')),
  );

  List<_Grower> growers = const [_Grower('Ana'), _Grower('Bea')];

  /// Opens [grower].
  void open(_Grower grower) =>
      growers = [...growers.where((other) => other != grower)];

  @override
  List<AgentCapability> get agentCapabilities => [.sees(growers), .calls(open)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [
      AgentView.of(() => growers).as('growers', 'The growers.', .list(_grower)),
    ],
    calls: [
      AgentTool(
        open,
        name: 'open',
        description: 'Opens grower.',
        parameters: [AgentParameter<_Grower>('grower', _grower)],
        invoke: (args) {
          open(args.read('grower'));
          return null;
        },
      ),
    ],
  );
}

final class const _Grower(final String name);

/// A view that shows what the agent sends with `"fits": true`.
final class _Canvas() implements ViewTool {
  @override
  Map<String, Object?> definition(AgentListing listing) => {
    'name': ViewTool.name,
    'description': 'Draws a view.',
    'parameters': {'type': 'object'},
  };

  @override
  ToolAnswer show(Map<String, Object?> arguments) => arguments['fits'] == true
      ? ToolAnswer.shown
      : .refused('It does not fit.');
}

/// A screen whose method that needs approval takes two arguments.
final class _Mailbox() implements AgentSurface {
  final sent = <String>[];

  void post(String to, String text) => sent.add('$to: $text');

  @override
  List<AgentCapability> get agentCapabilities => [.callsWithApproval(post)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [],
    calls: [
      AgentTool(
        post,
        name: 'post',
        description: 'Posts [text] to [to].',
        parameters: const [
          AgentParameter<String>('to', .string),
          AgentParameter<String>('text', .string),
        ],
        invoke: (args) {
          post(args.read('to'), args.read('text'));
          return null;
        },
      ),
    ],
  );
}

/// A screen whose color converter has a bug.
final class _Palette() implements AgentSurface {
  static final AgentType<int> _color = .converted(
    const _BrokenConverter(),
    AgentType.string,
    id: 'test#Color',
    converterId: 'test#BrokenConverter()',
  );

  void paint(int color) {}

  void order(int color) {}

  @override
  List<AgentCapability> get agentCapabilities => [
    .calls(paint),
    .callsWithApproval(order),
  ];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [],
    calls: [
      for (final (name, method) in [('paint', paint), ('order', order)])
        AgentTool(
          method,
          name: name,
          description: 'Uses [color].',
          parameters: [AgentParameter<int>('color', _color)],
          invoke: (args) {
            method(args.read('color'));
            return null;
          },
        ),
    ],
  );
}

final class const _BrokenConverter() implements JsonConverter<int, String> {
  @override
  int fromJson(String json) => throw StateError('A bug of the app.');

  @override
  String toJson(int object) => '$object';
}

Map<String, Object?> _toolStart(String id, String tool, {String? parent}) => {
  'type': 'TOOL_CALL_START',
  'toolCallId': id,
  'toolCallName': tool,
  'parentMessageId': ?parent,
};

Map<String, Object?> _toolArgs(String id, String delta) => {
  'type': 'TOOL_CALL_ARGS',
  'toolCallId': id,
  'delta': delta,
};
