import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

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
  }) {
    final session = TandemSession(
      surface: shop,
      connection: connection,
      onEvent: onEvent ?? events.add,
    );
    addTearDown(session.dispose);
    return session;
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

  test('a call runs at once and its result goes in the next run', () async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('find_customer', {'q': 'Acme'}),
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Done.')],
    ]);
    final session = open(agent)..send('add milk');
    await pumpEventQueue();

    expect(shop.items, ['milk']);
    expect(agent.requests, hasLength(2));
    final messages = messagesOf(agent.requests[1]);
    expect(messages.skip(messages.length - 2), [
      {
        'id': 'asst-call-2',
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'call-2',
            'type': 'function',
            'function': {'name': 'add', 'arguments': '{"item":"milk"}'},
          },
        ],
      },
      {
        'id': 'tool-call-2',
        'role': 'tool',
        'toolCallId': 'call-2',
        'content': 'null',
      },
    ]);
    expect(
      jsonEncode(agent.requests[1]),
      isNot(anyOf(contains('call-1'), contains('find_customer'))),
    );
    final [AgentCall(:tool, :arguments, :result)] = agentCalls();
    expect((tool, result), ('add', null));
    expect(arguments, {'item': 'milk'});
    expect(_shown(session.items), [
      ('user', 'add milk'),
      ('agent', 'Done.', false),
    ]);
  });

  test('calls go back in the message the server names, and its own calls with their results', () async {
    final connection = _RawFirstRun(
      Stream.fromIterable([
        {
          'type': 'TOOL_CALL_START',
          'toolCallId': 'b1',
          'toolCallName': 'find_customer',
          'parentMessageId': 'm1',
        },
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'b1', 'delta': '{"q":"A"}'},
        {
          'type': 'TOOL_CALL_RESULT',
          'messageId': 'r1',
          'toolCallId': 'b1',
          'content': '[]',
        },
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm2', 'delta': 'Adding.'},
        {
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c1',
          'toolCallName': 'add',
          'parentMessageId': 'm2',
        },
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': '{"item":"x"}'},
        // No result: the server's call stays out.
        {
          'type': 'TOOL_CALL_START',
          'toolCallId': 'b2',
          'toolCallName': 'lookup',
          'parentMessageId': 'm2',
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
    expect(messagesOf(connection.requests[1]).skip(1), [
      {
        'id': 'm1',
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'b1',
            'type': 'function',
            'function': {'name': 'find_customer', 'arguments': '{"q":"A"}'},
          },
        ],
      },
      {'id': 'r1', 'role': 'tool', 'toolCallId': 'b1', 'content': '[]'},
      {
        'id': 'm2',
        'role': 'assistant',
        'content': 'Adding.',
        'toolCalls': [
          {
            'id': 'c1',
            'type': 'function',
            'function': {'name': 'add', 'arguments': '{"item":"x"}'},
          },
        ],
      },
      {'id': 'tool-c1', 'role': 'tool', 'toolCallId': 'c1', 'content': 'null'},
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

  test('Thinking names a tool of the backend from its start until its result '
      'or the next text', () async {
    final stream = StreamController<Map<String, Object?>>();
    addTearDown(stream.close);
    final session = open(_RawFirstRun(stream.stream, ScriptedAgent([])))
      ..send('find a monitor');
    final statuses = <SessionStatus>[];
    session.addListener(() {
      if (statuses.lastOrNull != session.status) {
        statuses.add(session.status);
      }
    });

    for (final event in [
      {
        'type': 'TOOL_CALL_START',
        'toolCallId': 'c1',
        'toolCallName': 'search_catalog',
      },
      {
        'type': 'TOOL_CALL_RESULT',
        'messageId': 'r1',
        'toolCallId': 'c1',
        'content': '[]',
      },
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c2', 'toolCallName': 'lookup'},
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'None.'},
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c3', 'toolCallName': 'add'},
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
    expect(_shown(session.items), [
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
    expect(_shown(session.items), [
      ('user', 'go'),
      ('agent', 'Working', true),
      ('user', 'next'),
      ('agent', 'Hi', false),
    ]);
    expect(events, [isA<RunStopped>()]);
    expect(_lines(agent.requests[1]), [
      'user: go',
      'assistant: Working',
      'asst-call-1 add {"item":"x"}',
      'tool-call-1 {"status":"cancelled"}',
      'user: next',
    ]);
    expect(agent.requests, hasLength(2));
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
      final reported = _collectReports();
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
      expect(_shown(session.items), [('user', 'a'), ChatNoticeKind.runFailed]);

      session.send('b');
      await pumpEventQueue();
      expect(_shown(session.items).last, ('agent', 'Hi', false));
      // A run that ended with RUN_ERROR keeps its thread and history.
      expect(agent.requests[2]['threadId'], agent.requests[0]['threadId']);
      expect(_lines(agent.requests[2]), [
        ..._lines(agent.requests[1]),
        'user: b',
      ]);
    },
  );

  test('onEvent can send at once after a failed run', () async {
    _collectReports();
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
    expect(_lines(agent.requests.single), ['user: hi\n\nagain']);
    expect(session.status, isA<Idle>());
  });

  test('startOver after a failed run sends the next message to a new thread '
      'without the earlier history', () async {
    _collectReports();
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
    expect(_lines(agent.requests[2]), ['user: c']);
    expect(_shown(session.items), [
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
    _collectReports();
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

    expect(_lines(agent.requests.single), ['user: hi\n\nagain']);
  });

  test('startOver keeps a message whose connection threw before the run went '
      'out', () async {
    _collectReports();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Fresh.')],
    ]);
    late final TandemSession session;
    session = open(
      _ThrowsFirst(agent),
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

    expect(_lines(agent.requests.single), ['user: hi\n\nagain']);
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
    expect(_shown(session.items).last, ('user', 'again'));
    await pumpEventQueue();
    expect(_lines(agent.requests.last), ['user: again']);
  });

  test('a throwing onEvent is reported; the next message works', () async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'milk'}),
      ],
      (_) => const [AgentStep.say('Done.')],
      (_) => const [AgentStep.say('Hi')],
    ]);
    final reported = _collectReports();
    final session = open(
      agent,
      onEvent: (_) => throw StateError('listener failed'),
    )..send('add milk');
    await pumpEventQueue();

    expect(reported.single.exception, isStateError);
    expect(_lines(agent.requests[1]).last, 'tool-call-1 null');

    session.send('hello?');
    await pumpEventQueue();
    expect(_shown(session.items).last, ('agent', 'Hi', false));
  });

  test('the pieces of one message grow one item until the run ends', () async {
    final connection = _RawFirstRun(
      Stream.fromIterable([
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'Hel'},
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'lo'},
        {'type': 'RUN_FINISHED'},
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': ' late'},
      ]),
      ScriptedAgent([]),
    );
    final session = open(connection)..send('a');
    await pumpEventQueue();

    expect(_shown(session.items), [('user', 'a'), ('agent', 'Hello', false)]);
  });

  test(
    'events after the end of a run change nothing while its calls run',
    () async {
      final serverReply = Completer<void>();
      shop.serverReply = serverReply.future;
      final first = StreamController<Map<String, Object?>>();
      final connection = _RawFirstRun(
        first.stream,
        ScriptedAgent([
          (_) => const [AgentStep.say('Done.')],
        ]),
      );
      final session = open(connection)..send('a');
      first
        ..add({
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c1',
          'toolCallName': 'refresh',
        })
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
      expect(_shown(session.items), [('user', 'a'), ('agent', 'Done.', false)]);
    },
  );

  test(
    'a broken stream shows connection lost and starts a new thread',
    () async {
      final connection = _RawFirstRun(
        Stream.value({'type': 'RUN_STARTED'}),
        ScriptedAgent([
          (_) => const [AgentStep.say('Back')],
        ]),
      );
      final session = open(connection)..send('a');
      await pumpEventQueue();
      expect(_shown(session.items), [
        ('user', 'a'),
        ChatNoticeKind.connectionLost,
      ]);
      expect(events, [isA<ConnectionLost>()]);

      session.send('b');
      await pumpEventQueue();
      final [first, second] = connection.requests;
      expect(second['threadId'], isNot(first['threadId']));
      expect(_lines(second), ['user: b']);
      expect(_shown(session.items).last, ('agent', 'Back', false));
    },
  );

  test('a stream error is reported and shows connection lost', () async {
    const error = AgentHttpException(422, 'messages: field required');
    final reported = _collectReports();
    final session = open(_RawFirstRun(Stream.error(error), ScriptedAgent([])))
      ..send('a');
    await pumpEventQueue();

    expect(reported.single.exception, error);
    expect('${reported.single.exception}', contains('422'));
    expect(_shown(session.items).last, ChatNoticeKind.connectionLost);
  });

  test('an ambiguous chunk breaks the run: the response is cancelled, the '
      'error reported, and the next message starts a new thread', () async {
    var responseCancelled = false;
    // The server keeps the response open, so only the session can end it.
    final response =
        StreamController<List<int>>(onCancel: () => responseCancelled = true)
          ..add(
            utf8.encode(
              [
                {'type': 'RUN_STARTED'},
                {
                  'type': 'TEXT_MESSAGE_CHUNK',
                  'messageId': 'm1',
                  'subagentRunId': 's1',
                  'delta': 'A',
                },
                {
                  'type': 'TEXT_MESSAGE_CHUNK',
                  'messageId': 'm2',
                  'subagentRunId': 's2',
                  'delta': 'B',
                },
                {'type': 'TEXT_MESSAGE_CHUNK', 'delta': 'C'},
              ].map((event) => 'data: ${jsonEncode(event)}\n\n').join(),
            ),
          );
    final client = MockClient.streaming(
      (request, bodyStream) async =>
          http.StreamedResponse(response.stream, 200),
    );
    final connection = _RawFirstRun(
      HttpAgentConnection(
        Uri.parse('http://localhost/agent'),
        client: client,
      ).run(const {}),
      ScriptedAgent([
        (_) => const [AgentStep.say('Back')],
      ]),
    );
    final reported = _collectReports();
    final session = open(connection)..send('a');
    await pumpEventQueue();

    expect(responseCancelled, isTrue);
    expect(reported.single.exception, isFormatException);
    expect(_shown(session.items), [
      ('user', 'a'),
      ('agent', 'A', false),
      ('agent', 'B', false),
      ChatNoticeKind.connectionLost,
    ]);

    session.send('b');
    await pumpEventQueue();
    final [first, second] = connection.requests;
    expect(second['threadId'], isNot(first['threadId']));
    expect(_lines(second), ['user: b']);
    expect(_shown(session.items).last, ('agent', 'Back', false));
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
    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 null',
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

    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 {"status":"rejected_by_user"}',
    ]);
    expect(shop.items, ['x']);
    expect(_card(session).status, ApprovalStatus.rejected);
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
    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 ${ToolAnswer.invalidated.content}',
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
      final reported = _collectReports();
      final (session, _) = await askToClear();

      shop
        ..listThrows = true
        ..showTab(1);
      await pumpEventQueue();

      expect(_card(session).status, ApprovalStatus.invalidated);
      expect(reported.single.exception, isStateError);
    },
  );

  test('a change to .sees while the agent thinks invalidates its request '
      'before it shows', () async {
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

    shop.add('y');
    gate.complete();
    await pumpEventQueue();

    expect(session.items.whereType<ApprovalRequest>(), isEmpty);
    expect(
      _lines(agent.requests[1]).last,
      'tool-call-1 ${ToolAnswer.invalidated.content}',
    );
  });

  test('a change to .sees that `changes` never reports, made while the agent '
      'thinks, invalidates its request before it shows', () async {
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

    shop.items.add('y');
    gate.complete();
    await pumpEventQueue();

    expect(session.items.whereType<ApprovalRequest>(), isEmpty);
    expect(
      _lines(agent.requests[1]).last,
      'tool-call-1 ${ToolAnswer.invalidated.content}',
    );
  });

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
      expect(_lines(agent.requests[1]), [
        'user: go',
        'asst-call-1 add {"item":"y"}',
        'asst-call-2 clear {}',
        'tool-call-1 null',
        'tool-call-2 ${ToolAnswer.invalidated.content}',
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
    final reported = _collectReports();
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
    final reported = _collectReports();
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
    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 null',
    ]);
    expect(_shown(session.items), [
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
    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 {"status":"cancelled"}',
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
    expect(_lines(agent.requests[1]), [
      'user: add bread',
      'asst-call-1 add {"item":"bread"}',
      'tool-call-1 null',
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
    expect(_shown(session.items), [
      ('user', 'hi'),
      ('agent', 'Hi.', false),
      ('user', 'again'),
      ('agent', 'Hi again.', false),
    ]);
  });

  test('the notes stay new when the run that offered them fails', () async {
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

  test('wake starts a run with a message from the app, which waits while a '
      'request waits and goes with the run after the decision', () async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Nothing new.')],
      (_) => const [AgentStep.callTool('share'), AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Shared twice.')],
    ]);
    final session = open(agent)..wake();
    await pumpEventQueue();
    expect(_lines(agent.requests.single).single, startsWith('user: The app'));
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
    expect(_shown(session.items).last, ('share', ApprovalStatus.pending));
    expect(agent.requests, hasLength(2));

    session.approve(session.items.whereType<ApprovalRequest>().last);
    await pumpEventQueue();
    expect(_lines(agent.requests[2]).skip(3), [
      'asst-call-1 share {}',
      'asst-call-2 share {}',
      'tool-call-1 null',
      'tool-call-2 null',
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
      _lines(agent.requests[1]).last,
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
    expect(_lines(agent.requests[1]).skip(1), [
      'asst-call-1 share {}',
      'tool-call-1 null',
      startsWith('user: The app'),
    ]);
    expect(_shown(session.items).last, ('agent', 'Shared.', false));
  });

  test('a call with arguments that are not an object is refused without a '
      'card or a report', () async {
    shop.add('x');
    final connection = _RawFirstRun(
      Stream.fromIterable([
        {'type': 'TOOL_CALL_START', 'toolCallId': 'c1', 'toolCallName': 'add'},
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': '{"item":'},
        {
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c2',
          'toolCallName': 'clear',
        },
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c2', 'delta': '[]'},
        {'type': 'RUN_FINISHED'},
      ]),
      ScriptedAgent([
        (_) => const [AgentStep.say('Sorry.')],
      ]),
    );
    final reported = _collectReports();
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
    expect(_shown(session.items).last, ('share', ApprovalStatus.approved));

    serverReply.complete();
    await pumpEventQueue();
    expect(_shown(session.items).skip(1), [
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
    expect(_lines(agent.requests[1]).skip(3), [
      'tool-call-1 null',
      'tool-call-2 ${ToolAnswer.invalidated.content}',
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
    final reported = _collectReports();
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
    expect(_lines(agent.requests[1]).skip(3), [
      'tool-call-1 {"status":"rejected_by_user"}',
      'tool-call-2 {"status":"cancelled"}',
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
    expect(_lines(agent.requests[1]), [
      'user: go',
      'asst-call-1 refresh {}',
      'asst-call-2 clear {}',
      'tool-call-1 null',
      'tool-call-2 null',
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
        _lines(agent.requests[1]).last,
        'tool-call-2 ${ToolAnswer.invalidated.content}',
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

  test(
    'an unsupported outcome discards calls and preserves queued user input',
    () async {
      var responseCancelled = false;
      final stream = StreamController<Map<String, Object?>>(
        onCancel: () => responseCancelled = true,
      );
      final connection = _RawFirstRun(
        stream.stream,
        ScriptedAgent([
          (_) => const [AgentStep.say('New conversation.')],
        ]),
      );
      final reported = _collectReports();
      final session = open(connection)..send('go');
      stream
        ..add({
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c1',
          'toolCallName': 'add',
        })
        ..add({
          'type': 'TOOL_CALL_ARGS',
          'toolCallId': 'c1',
          'delta': '{"item":"x"}',
        })
        ..add({
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c2',
          'toolCallName': 'share',
        });
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
      expect(_shown(session.items).last, ChatNoticeKind.runFailed);
      expect(reported.single.exception, isA<AgentRunException>());
      expect(events, [isA<RunFailed>()]);

      session.send('next');
      await pumpEventQueue();

      final [first, second] = connection.requests;
      expect(second['threadId'], isNot(first['threadId']));
      expect(_lines(second), ['user: queued\n\nalso queued\n\nnext']);
    },
  );

  test(
    'a cancelled outcome stops without executing calls or asking for approval',
    () async {
      final connection = _RawFirstRun(
        Stream.fromIterable([
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'add',
          },
          {
            'type': 'TOOL_CALL_ARGS',
            'toolCallId': 'c1',
            'delta': '{"item":"x"}',
          },
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c2',
            'toolCallName': 'share',
          },
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
      expect(_shown(session.items).last, ChatNoticeKind.stopped);
      expect(events, [isA<RunStopped>()]);

      session.send('next');
      await pumpEventQueue();

      expect(_lines(connection.requests[1]), [
        'user: go',
        'asst-c1 add {"item":"x"}',
        'asst-c2 share {}',
        'tool-c1 {"status":"cancelled"}',
        'tool-c2 {"status":"cancelled"}',
        'user: next',
      ]);
    },
  );

  test(
    'a reopened tool preserves arguments and a changed method fails closed',
    () async {
      final reported = _collectReports();
      final connection = _RawFirstRun(
        Stream.fromIterable([
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'add',
          },
          {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': '{"item":'},
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'add',
          },
          {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': '"x"}'},
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
      expect(_lines(connection.requests[1])[1], 'asst-c1 add {"item":"x"}');

      final conflicting = _RawFirstRun(
        Stream.fromIterable([
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'add',
          },
          {
            'type': 'TOOL_CALL_ARGS',
            'toolCallId': 'c1',
            'delta': '{"item":"y"}',
          },
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'transfer_to_agent',
          },
          {'type': 'RUN_FINISHED'},
        ]),
        ScriptedAgent([]),
      );
      final second = open(conflicting)..send('conflicting');
      await pumpEventQueue();
      expect(shop.items, ['x']);
      expect(conflicting.requests, hasLength(1));
      expect(_shown(second.items).last, ChatNoticeKind.runFailed);
      expect(reported.single.exception, isFormatException);
    },
  );
}

ApprovalRequest _card(TandemSession session) =>
    session.items.whereType<ApprovalRequest>().single;

final class _RawFirstRun(
  final Stream<Map<String, Object?>> _first,
  final ScriptedAgent _agent,
) implements AgentConnection {
  final requests = <Map<String, Object?>>[];

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    requests.add(input);
    return requests.length == 1 ? _first : _agent.run(input);
  }
}

/// Throws on its first run before any stream exists, as an adapter that
/// checks its input can.
final class _ThrowsFirst(final ScriptedAgent _agent)
    implements AgentConnection {
  var _runs = 0;

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    if (_runs++ == 0) {
      throw StateError('No token.');
    }
    return _agent.run(input);
  }
}

List<FlutterErrorDetails> _collectReports() {
  final reported = <FlutterErrorDetails>[];
  final onError = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = onError);
  return reported;
}

List<String> _lines(Map<String, Object?> request) => [
  for (final message in messagesOf(request))
    switch (message) {
      {'role': 'tool', 'id': final id, 'content': final content} =>
        '$id $content',
      {
        'id': final id,
        'toolCalls': [
          {'function': {'name': final name, 'arguments': final arguments}},
        ],
      } =>
        '$id $name $arguments',
      {'role': final role, 'content': final content} => '$role: $content',
      _ => '$message',
    },
];

List<Object> _shown(List<ChatItem> items) => [
  for (final item in items)
    switch (item) {
      UserMessage(:final text) => ('user', text),
      AgentMessage(:final text, :final stopped) => ('agent', text, stopped),
      ChatNotice(:final kind) => kind,
      ApprovalRequest(:final tool, :final status) => (tool, status),
    },
];
