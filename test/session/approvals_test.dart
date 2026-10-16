// Approval requests: a tool with needsApproval runs only after the user
// approves that exact call while the shared state is unchanged.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'support.dart';

const _line = {'sku': 'HDMI-2M', 'quantity': 40, 'unitPrice': 8.55};

/// The first turn of most tests: fill a line, then propose placing the
/// order.
List<AgentStep> _propose(RunRequest _) => const [
  AgentStep.patchState([
    {'op': 'add', 'path': '/order/lines/-', 'value': _line},
  ]),
  AgentStep.callTool('place_order', {'channel': 'email'}),
];

/// The hosts some tests run with: a synchronous one and one that delivers
/// like bloc, each with the way the user edits it.
final _hosts =
    <
      String,
      ({
        StateHost<OrderDraft> host,
        void Function(OrderDraft Function(OrderDraft current) edit) update,
      })
      Function()
    >{
      'MemoryStateHost': () {
        final host = MemoryStateHost(OrderDraft.empty);
        return (host: host, update: host.update);
      },
      'an asynchronous host': () {
        final host = AsyncHost(OrderDraft.empty);
        return (host: host, update: host.update);
      },
    };

void main() {
  late RecordingTool place;

  setUp(() {
    place = RecordingTool(
      'place_order',
      needsApproval: true,
      params: {'channel': const Param.string('How to confirm', optional: true)},
      result: const {'number': 'ZAM/2026/0042'},
    );
  });

  TandemSession<OrderDraft> newSession(
    AgentConnection agent,
    StateHost<OrderDraft> host, {
    List<Tool<OrderDraft>> tools = const [],
  }) => TandemSession(
    connection: agent,
    host: host,
    codec: orderCodec,
    tools: [place.tool, ...tools],
    options: quiet,
  );

  test('a proposal waits for the user; approving runs the tool with the '
      'approved state and reports it in a follow-up', () async {
    final answered = Completer<void>();
    final agent = ScriptedAgent([
      _propose,
      (request) {
        expect(request.userText, isNull);
        expect(request.resultOf('place_order'), {
          'status': 'executed',
          'approved': true,
          'result': {'number': 'ZAM/2026/0042'},
        });
        return [
          AgentStep.waitFor(answered.future),
          const AgentStep.say('Placed.'),
        ];
      },
    ]);
    final host = MemoryStateHost(OrderDraft.empty);
    final session = newSession(agent, host);

    await session.send('Place it');

    expect(session.view.isRunning, isFalse);
    final request = session.view.openApprovals.single;
    expect(request.status, ApprovalStatus.pending);
    expect(request.canApprove, isTrue);
    expect(request.canReject, isTrue);
    expect(request.isStale, isFalse);
    expect(request.args.read<String>('channel'), 'email');
    expect(place.calls, isEmpty);

    await request.approve();

    // It completes when the tool has run; the follow-up is under way.
    expect(place.calls.single.state, host.state);
    expect(place.calls.single.read<String>('channel'), 'email');
    expect(session.view.isRunning, isTrue);
    final executed = session.view.timeline.whereType<ApprovalRequest>().single;
    expect(executed.status, ApprovalStatus.executed);
    expect(executed.result, {'number': 'ZAM/2026/0042'});
    expect(session.view.openApprovals, isEmpty);

    answered.complete();
    await pumpEventQueue();
    expect(agent.isExhausted, isTrue);
    expect(session.view.isRunning, isFalse);
    expect(session.view.error, isNull);
    await session.dispose();
  });

  test('approve is a no-op unless pending, so a double tap runs the tool '
      'once', () async {
    final agent = ScriptedAgent([
      _propose,
      (_) => const [AgentStep.say('Placed.')],
    ]);
    final session = newSession(agent, MemoryStateHost(OrderDraft.empty));

    await session.send('Place it');
    final request = session.view.openApprovals.single;
    final first = request.approve();
    final second = request.approve();
    await Future.wait([first, second]);
    await request.approve();
    await request.reject();
    await pumpEventQueue();

    expect(place.calls, hasLength(1));
    expect(agent.isExhausted, isTrue);
    expect(session.view.error, isNull);
    await session.dispose();
  });

  test('a user edit makes the request stale for good; it can still be '
      'rejected', () async {
    final agent = ScriptedAgent([
      _propose,
      (request) {
        expect(request.resultOf('place_order'), {
          'status': 'rejected',
          'approved': false,
        });
        expect(request.reportedUserEdits, ['/order/lines/0/quantity']);
        return const [AgentStep.say('Not placing it.')];
      },
    ]);
    final host = MemoryStateHost(OrderDraft.empty);
    final session = newSession(agent, host);

    await session.send('Place it');
    final proposed = session.view.openApprovals.single;
    host.update((draft) => draft.withQuantity(0, 50));

    final stale = session.view.openApprovals.single;
    expect(stale.status, ApprovalStatus.stale);
    expect(stale.isStale, isTrue);
    expect(stale.canApprove, isFalse);
    expect(stale.canReject, isTrue);

    // Changing the value back does not make it approvable again.
    host.update((draft) => draft.withQuantity(0, 40));
    expect(session.view.openApprovals.single.status, ApprovalStatus.stale);
    // A view taken before the edit cannot approve either.
    await proposed.approve();
    expect(place.calls, isEmpty);
    expect(agent.requests, hasLength(1));

    await session.view.openApprovals.single.reject();
    await pumpEventQueue();

    expect(place.calls, isEmpty);
    expect(agent.isExhausted, isTrue);
    expect(
      session.view.timeline.whereType<ApprovalRequest>().single.status,
      ApprovalStatus.rejected,
    );
    expect(session.view.openApprovals, isEmpty);
    await session.dispose();
  });

  for (final MapEntry(key: hostName, value: newHost) in _hosts.entries) {
    test('a user edit during the run that proposes makes the request stale '
        'at once ($hostName)', () async {
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (request) => [..._propose(request), AgentStep.waitFor(typed.future)],
        (request) {
          expect(request.resultOf('place_order'), {
            'status': 'invalidated',
            'approved': false,
            'reason': 'state_changed',
          });
          expect(request.reportedUserEdits, ['/order/lines/0/quantity']);
          return const [AgentStep.say('Proposing 400 then.')];
        },
      ]);
      final (:host, :update) = newHost();
      final session = newSession(agent, host);

      final sending = session.send('Place it');
      await pumpEventQueue();
      // The agent proposed 40 cables; before its run ends, the user types
      // 400, which the agent never saw.
      update((draft) => draft.withQuantity(0, 400));
      typed.complete();
      await sending;

      final request = session.view.openApprovals.single;
      expect(request.status, ApprovalStatus.stale);
      await request.approve();
      expect(place.calls, isEmpty);

      await session.send('I want 400');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });
  }

  test('an edit an asynchronous host has not delivered when the run that '
      'proposes ends makes the request stale', () async {
    final runs = StreamController<WireEvent>(sync: true);
    final connection = ManualConnection([(_) => runs.stream]);
    final host = AsyncHost(OrderDraft.empty);
    final session = newSession(connection, host);

    final sending = session.send('Place it');
    for (final event in [
      {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
      {
        'type': 'TOOL_CALL_START',
        'toolCallId': 'call-1',
        'toolCallName': 'place_order',
      },
      {'type': 'TOOL_CALL_END', 'toolCallId': 'call-1'},
      {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r1'},
    ]) {
      runs.add(WireEvent.fromJson(event));
    }
    // In the same go as the last event: the host delivers it only later.
    host.update((draft) => draft.copyWith(notes: 'Urgent'));
    await runs.close();
    await sending;

    expect(session.view.openApprovals.single.status, ApprovalStatus.stale);
    await session.dispose();
  });

  test('a user edit the agent overwrote later in the same run does not make '
      'its request stale', () async {
    final typed = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [
        const AgentStep.patchState([
          {'op': 'add', 'path': '/order/lines/-', 'value': _line},
        ]),
        AgentStep.waitFor(typed.future),
        const AgentStep.patchState([
          {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
        ]),
        const AgentStep.callTool('place_order'),
      ],
    ]);
    final host = MemoryStateHost(OrderDraft.empty);
    final session = newSession(agent, host);

    final sending = session.send('Place it, urgent');
    await pumpEventQueue();
    host.update((draft) => draft.copyWith(notes: 'Call first'));
    typed.complete();
    await sending;

    // The agent wrote the notes last, so it proposed against what is shown.
    expect(host.state.notes, 'Urgent');
    expect(session.view.openApprovals.single.status, ApprovalStatus.pending);
    await session.dispose();
  });

  test('an edit just before send, not delivered yet by an asynchronous host, '
      'invalidates a pending request', () async {
    final agent = ScriptedAgent([
      _propose,
      (request) {
        expect(request.resultOf('place_order'), {
          'status': 'invalidated',
          'approved': false,
          'reason': 'state_changed',
        });
        expect(request.reportedUserEdits, ['/order/notes']);
        return const [AgentStep.say('Proposing again.')];
      },
    ]);
    final host = AsyncHost(OrderDraft.empty);
    final session = newSession(agent, host);

    await session.send('Place it');
    expect(session.view.openApprovals.single.canApprove, isTrue);
    host.update((draft) => draft.copyWith(notes: 'Urgent'));
    await session.send('I added a note');

    expect(agent.isExhausted, isTrue);
    expect(session.view.error, isNull);
    await session.dispose();
  });

  test('the proposal of a stopped run stays in the timeline as '
      'dismissed', () async {
    final never = Completer<void>();
    // Without mimicAdk the call ends at once; ag-ui-adk would end it only
    // after its final snapshot, so a stop would drop it.
    final agent = ScriptedAgent(mimicAdk: false, [
      (_) => [
        const AgentStep.callTool('place_order', {'channel': 'email'}),
        AgentStep.waitFor(never.future),
      ],
      (request) {
        expect(request.resultOf('place_order'), {'status': 'cancelled'});
        return const [AgentStep.say('OK.')];
      },
    ]);
    final session = newSession(agent, MemoryStateHost(OrderDraft.empty));

    unawaited(session.send('Place it'));
    await pumpEventQueue();
    await session.stop();

    final request = session.view.timeline.whereType<ApprovalRequest>().single;
    expect(request.status, ApprovalStatus.dismissed);
    expect(request.args.read<String>('channel'), 'email');
    expect(session.view.openApprovals, isEmpty);
    await request.approve();
    expect(place.calls, isEmpty);

    await session.send('Never mind');

    expect(agent.isExhausted, isTrue);
    await session.dispose();
  });

  test('approve re-checks the live state, even before an asynchronous host '
      'delivers the edit', () async {
    final agent = ScriptedAgent([_propose]);
    final host = AsyncHost(OrderDraft.empty);
    final session = newSession(agent, host);

    await session.send('Place it');
    final request = session.view.openApprovals.single;
    host.update((draft) => draft.withQuantity(0, 50));
    expect(request.canApprove, isTrue);

    await request.approve();

    expect(place.calls, isEmpty);
    expect(session.view.openApprovals.single.status, ApprovalStatus.stale);
    await session.dispose();
  });

  test("a request refers to the state after all of its run's state "
      'events', () async {
    final agent = ScriptedAgent(mimicAdk: false, [
      (_) => const [
        AgentStep.callTool('place_order', {'channel': 'email'}),
        AgentStep.patchState([
          {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
        ]),
      ],
    ]);
    final host = MemoryStateHost(OrderDraft.empty);
    final session = newSession(agent, host);

    await session.send('Place it, urgent');

    expect(host.state.notes, 'Urgent');
    expect(session.view.openApprovals.single.status, ApprovalStatus.pending);
    await session.dispose();
  });

  test('an approved tool that throws is reported as failed', () async {
    final failing = RecordingTool(
      'place_order',
      needsApproval: true,
      error: const OutOfStock(),
    );
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('place_order')],
      (request) {
        expect(request.resultOf('place_order'), {
          'status': 'failed',
          'approved': true,
          'error': 'Out of stock',
        });
        return const [AgentStep.say('It failed.')];
      },
    ]);
    final session = TandemSession(
      connection: agent,
      host: MemoryStateHost(OrderDraft.empty),
      codec: orderCodec,
      tools: [failing.tool],
      options: quiet,
    );

    await session.send('Place it');
    await session.view.openApprovals.single.approve();
    await pumpEventQueue();

    final request = session.view.timeline.whereType<ApprovalRequest>().single;
    expect(request.status, ApprovalStatus.failed);
    expect(request.failure, 'Out of stock');
    expect(agent.isExhausted, isTrue);
    expect(session.view.error, isNull);
    await session.dispose();
  });

  test('a message sent while a request is pending dismisses it; the answer '
      'comes before the message', () async {
    final agent = ScriptedAgent([
      _propose,
      (request) {
        expect(request.resultOf('place_order'), {
          'status': 'dismissed',
          'approved': false,
          'reason': 'user_sent_message',
        });
        expect(request.userText, 'Add a monitor first');
        expect(request.input.messages.last, isA<WireUserMessage>());
        expect(
          request.input.messages[request.input.messages.length - 2],
          isA<WireToolMessage>(),
        );
        return const [AgentStep.say('Adding a monitor.')];
      },
    ]);
    final session = newSession(agent, MemoryStateHost(OrderDraft.empty));

    await session.send('Place it');
    final request = session.view.openApprovals.single;
    await session.send('Add a monitor first');

    expect(agent.isExhausted, isTrue);
    expect(place.calls, isEmpty);
    expect(session.view.openApprovals, isEmpty);
    expect(
      session.view.timeline.whereType<ApprovalRequest>().single.status,
      ApprovalStatus.dismissed,
    );
    await request.approve();
    expect(place.calls, isEmpty);
    await session.dispose();
  });

  test('a message sent while a request is stale invalidates it', () async {
    final agent = ScriptedAgent([
      _propose,
      (request) {
        expect(request.resultOf('place_order'), {
          'status': 'invalidated',
          'approved': false,
          'reason': 'state_changed',
        });
        expect(request.userText, 'I changed the quantity');
        return const [AgentStep.say('Proposing again.')];
      },
    ]);
    final host = MemoryStateHost(OrderDraft.empty);
    final session = newSession(agent, host);

    await session.send('Place it');
    host.update((draft) => draft.withQuantity(0, 50));
    await session.send('I changed the quantity');

    expect(agent.isExhausted, isTrue);
    expect(session.view.openApprovals, isEmpty);
    expect(session.view.error, isNull);
    await session.dispose();
  });

  test('with two requests, one follow-up carries both decisions after the '
      'last one', () async {
    final discount = RecordingTool(
      'apply_discount',
      needsApproval: true,
      result: 15,
    );
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('apply_discount', {'percent': 15}),
        AgentStep.callTool('place_order'),
      ],
      (request) {
        expect(request.resultOf('apply_discount'), {
          'status': 'executed',
          'approved': true,
          'result': 15,
        });
        expect(request.resultOf('place_order'), {
          'status': 'rejected',
          'approved': false,
        });
        return const [AgentStep.say('Discount applied, order not placed.')];
      },
    ]);
    final session = newSession(
      agent,
      MemoryStateHost(OrderDraft.empty),
      tools: [discount.tool],
    );

    await session.send('15% and place it');
    final [first, second] = session.view.openApprovals;
    expect(first.toolName, 'apply_discount');
    expect(second.toolName, 'place_order');

    await first.approve();
    await pumpEventQueue();
    expect(agent.requests, hasLength(1));
    expect(session.view.isRunning, isFalse);

    await second.reject();
    await pumpEventQueue();

    expect(agent.isExhausted, isTrue);
    expect(discount.calls, hasLength(1));
    await session.dispose();
  });

  test('a tool without approval in the same run runs at once; its result '
      'waits for the decision', () async {
    final search = RecordingTool('search_catalog', result: const ['HDMI-2M']);
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('search_catalog', {'query': 'HDMI'}),
        AgentStep.callTool('place_order'),
      ],
      (request) {
        expect(request.resultOf('search_catalog'), {
          'status': 'ok',
          'result': ['HDMI-2M'],
        });
        expect(request.resultOf('place_order')?['status'], 'executed');
        return const [AgentStep.say('Done.')];
      },
    ]);
    final session = newSession(
      agent,
      MemoryStateHost(OrderDraft.empty),
      tools: [search.tool],
    );

    await session.send('Find and place');

    expect(search.calls, hasLength(1));
    expect(agent.requests, hasLength(1));
    await session.view.openApprovals.single.approve();
    await pumpEventQueue();

    expect(agent.isExhausted, isTrue);
    await session.dispose();
  });

  test(
    'a message sent during the run that proposes dismisses the proposal',
    () async {
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(typed.future),
          const AgentStep.callTool('place_order'),
        ],
        (request) {
          expect(request.resultOf('place_order')?['status'], 'dismissed');
          expect(request.userText, 'Wait, one more line');
          return const [AgentStep.say('OK.')];
        },
      ]);
      final session = newSession(agent, MemoryStateHost(OrderDraft.empty));

      final first = session.send('Place it');
      await pumpEventQueue();
      final second = session.send('Wait, one more line');
      typed.complete();
      await Future.wait([first, second]);

      expect(agent.isExhausted, isTrue);
      expect(place.calls, isEmpty);
      expect(session.view.openApprovals, isEmpty);
      await session.dispose();
    },
  );
}

/// What an order system throws when a product ran out.
final class OutOfStock implements Exception {
  const OutOfStock();

  @override
  String toString() => 'Out of stock';
}
