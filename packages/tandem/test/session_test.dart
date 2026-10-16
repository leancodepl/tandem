import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

import 'support/shop.dart';

void main() {
  late Shop shop;
  late List<List<Object?>> agentCalls;

  setUp(() {
    shop = Shop();
    agentCalls = [];
  });

  TandemSession open(
    AgentConnection connection, {
    AgentCallListener? onAgentCall,
  }) {
    final session = TandemSession(
      surface: shop,
      changes: shop.changes,
      connection: connection,
      onAgentCall:
          onAgentCall ??
          (tool, arguments, result) =>
              agentCalls.add([tool, arguments, result]),
    );
    addTearDown(session.dispose);
    return session;
  }

  /// A session whose agent asked to clear the list `['x']`. Its next run
  /// says `Cleared.`.
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
    final messages = _messages(agent.requests[1]);
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
    expect(agentCalls, [
      [
        'add',
        {'item': 'milk'},
        null,
      ],
    ]);
    expect(_shown(session.items), [
      ('user', 'add milk'),
      ('agent', 'Done.', false),
    ]);
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
    expect(session.isStopping, isTrue);
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
    'errors go back to the agent or into the chat; the next message works',
    () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('add', {'item': ''}),
        ],
        (_) => const [AgentStep.fail('boom')],
        (_) => const [AgentStep.say('Hi')],
      ]);
      final reported = _collectReports();
      final session = open(agent)..send('a');
      await pumpEventQueue();

      final answer = _messages(agent.requests[1]).last['content']! as String;
      expect(jsonDecode(answer), {
        'status': 'failed',
        'error': contains('item'),
      });
      expect(reported.map((details) => details.exception), [
        isArgumentError,
        isA<AgentRunException>().having(
          (err) => err.message,
          'message',
          'boom',
        ),
      ]);
      expect(agentCalls, isEmpty);
      expect(_shown(session.items), [('user', 'a'), ChatNoticeKind.runFailed]);

      session.send('b');
      await pumpEventQueue();
      expect(_shown(session.items).last, ('agent', 'Hi', false));
      expect(_lines(agent.requests[2]).last, 'user: b');
    },
  );

  test('a throwing onAgentCall is reported; the next message works', () async {
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
      onAgentCall: (_, _, _) => throw StateError('highlight'),
    )..send('add milk');
    await pumpEventQueue();

    expect(reported.single.exception, isStateError);
    expect(_lines(agent.requests[1]).last, 'tool-call-1 null');

    session.send('hello?');
    await pumpEventQueue();
    expect(_shown(session.items).last, ('agent', 'Hi', false));
  });

  test(
    'a broken stream shows connection lost and starts a new thread',
    () async {
      final connection = _BreaksFirstRun(
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
    final session = open(
      _BreaksFirstRun(Stream.error(error), ScriptedAgent([])),
    )..send('a');
    await pumpEventQueue();

    expect(reported.single.exception, error);
    expect('${reported.single.exception}', contains('422'));
    expect(_shown(session.items).last, ChatNoticeKind.connectionLost);
  });

  test('Approve runs the method once and continues', () async {
    final (session, agent) = await askToClear();
    final card = _card(session);
    expect(
      [card.tool, card.arguments, card.status],
      ['clear', <String, Object?>{}, ApprovalStatus.pending],
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
    expect(agentCalls, [
      ['clear', <String, Object?>{}, null],
    ]);
  });

  test('Reject answers rejected_by_user at once', () async {
    final (session, agent) = await askToClear();

    session.reject(_card(session));
    await pumpEventQueue();

    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 {"status":"rejected_by_user"}',
    ]);
    expect(shop.items, ['x']);
    expect(_card(session).status, ApprovalStatus.rejected);
  });

  test('an edit invalidates the card for good; the answer goes with the next '
      'message', () async {
    final (session, agent) = await askToClear();
    final card = _card(session);

    shop.add('y');
    await pumpEventQueue();
    expect(_card(session).status, ApprovalStatus.invalidated);
    session.approve(card);
    await pumpEventQueue();
    expect(shop.items, ['x', 'y']);
    expect(agent.requests, hasLength(1));

    session.send('ok');
    await pumpEventQueue();
    expect(_lines(agent.requests[1]), [
      'user: clear it',
      'asst-call-1 clear {}',
      'tool-call-1 {"status":"invalidated"}',
      'user: ok',
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

  test('several calls in one turn are answered in one run', () async {
    shop.add('x');
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add', {'item': 'y'}),
        AgentStep.callTool('clear'),
      ],
      (_) => const [AgentStep.say('Done.')],
    ]);
    final session = open(agent)..send('go');
    await pumpEventQueue();
    expect(shop.items, ['x', 'y']);
    expect(_card(session).status, ApprovalStatus.pending);
    expect(agent.requests, hasLength(1));

    session.approve(_card(session));
    await pumpEventQueue();

    expect(agent.requests, hasLength(2));
    expect(_lines(agent.requests[1]), [
      'user: go',
      'asst-call-1 add {"item":"y"}',
      'asst-call-2 clear {}',
      'tool-call-1 null',
      'tool-call-2 null',
    ]);
  });
}

/// The only approval card of [session], as the chat shows it now.
ApprovalRequest _card(TandemSession session) =>
    session.items.whereType<ApprovalRequest>().single;

/// A connection whose first run is [_first], such as a stream that ends
/// after `RUN_STARTED`. Later runs play [_agent].
final class _BreaksFirstRun(
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

/// Collects the errors reported to Flutter until the test ends.
List<FlutterErrorDetails> _collectReports() {
  final reported = <FlutterErrorDetails>[];
  final onError = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = onError);
  return reported;
}

List<Map<String, Object?>> _messages(Map<String, Object?> request) =>
    (request['messages']! as List<Object?>).cast();

/// The messages of [request], one line each: `user: go` for a text,
/// `asst-call-1 add {"item":"x"}` for a call, `tool-call-1 null` for its
/// answer.
List<String> _lines(Map<String, Object?> request) => [
  for (final message in _messages(request))
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

/// [items] as values that compare by value.
List<Object> _shown(List<ChatItem> items) => [
  for (final item in items)
    switch (item) {
      UserMessage(:final text) => ('user', text),
      AgentMessage(:final text, :final stopped) => ('agent', text, stopped),
      ChatNotice(:final kind) => kind,
      ApprovalRequest(:final tool, :final status) => (tool, status),
    },
];
