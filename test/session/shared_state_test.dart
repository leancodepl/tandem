// How the session keeps the shared state in sync with the agent: per-leaf
// last write wins, echoes told from user edits by content, reported user
// edits, agent marks, and the codecs and hosts it works through.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'support.dart';

const _acme = {'id': 'C-17', 'name': 'Acme Sp. z o.o.'};

const _hdmi = {'sku': 'HDMI-2M', 'quantity': 40, 'unitPrice': 8.55};
const _monitor = {'sku': 'MON-27', 'quantity': 12, 'unitPrice': 899};

const _twoLines = OrderDraft(
  lines: [
    OrderLine(sku: 'HDMI-2M', quantity: 40, unitPrice: 8.55),
    OrderLine(sku: 'MON-27', quantity: 12, unitPrice: 899),
  ],
);

/// A host the user edits, as a test sees it.
typedef _EditableHost = ({
  StateHost<OrderDraft> host,
  void Function(OrderDraft Function(OrderDraft current) edit) update,
});

/// The hosts every conflict test runs with: a synchronous one and one that
/// delivers like bloc.
final _hosts = <String, _EditableHost Function(OrderDraft initial)>{
  'MemoryStateHost': (initial) {
    final host = MemoryStateHost(initial);
    return (host: host, update: host.update);
  },
  'an asynchronous host': (initial) {
    final host = AsyncHost(initial);
    return (host: host, update: host.update);
  },
};

void main() {
  group('Conflicts', () {
    for (final MapEntry(key: hostName, value: newHost) in _hosts.entries) {
      test("the run's final snapshot does not revert a user edit made during "
          'the run ($hostName)', () async {
        final typed = Completer<void>();
        final agent = ScriptedAgent([
          (_) => [
            const AgentStep.patchState([
              {'op': 'replace', 'path': '/order/customer', 'value': _acme},
            ]),
            AgentStep.waitFor(typed.future),
            const AgentStep.say('Found Acme.'),
          ],
          (request) {
            expect(request.reportedUserEdits, ['/order/notes']);
            expect(
              (request.state['order']! as Map<String, Object?>)['notes'],
              'Urgent',
            );
            return const [AgentStep.say('Noted.')];
          },
        ]);
        final (:host, :update) = newHost(OrderDraft.empty);
        final session = TandemSession(
          connection: agent,
          host: host,
          codec: orderCodec,
          options: quiet,
        );

        final sending = session.send('Order for Acme');
        await pumpEventQueue();
        expect(host.state.customer, Customer.fromJson(_acme));
        update((draft) => draft.copyWith(notes: 'Urgent'));
        typed.complete();
        await sending;

        // ag-ui-adk's final snapshot still says notes: '', which the agent
        // knew already, so it is not a write.
        expect(host.state.notes, 'Urgent');
        expect(host.state.customer, Customer.fromJson(_acme));
        expect(session.view.marks.has('customer'), isTrue);
        expect(session.view.marks.has('notes'), isFalse);

        await session.send('Thanks');
        expect(agent.isExhausted, isTrue);
        expect(session.view.error, isNull);
        await session.dispose();
      });
    }

    test("the agent's later change of a leaf wins over the user's earlier "
        'edit of it', () async {
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(typed.future),
          const AgentStep.patchState([
            {
              'op': 'replace',
              'path': '/order/notes',
              'value': 'Deliver Friday',
            },
          ]),
        ],
      ]);
      final host = MemoryStateHost(OrderDraft.empty);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      final sending = session.send('Delivery on Friday');
      await pumpEventQueue();
      host.update((draft) => draft.copyWith(notes: 'Urgent'));
      typed.complete();
      await sending;

      expect(host.state.notes, 'Deliver Friday');
      expect(session.view.marks.has('notes'), isTrue);
      await session.dispose();
    });

    test('a list whose length the agent changed replaces the list as a '
        'whole; a user edit it reverts is marked and not reported', () async {
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(typed.future),
          const AgentStep.patchState([
            {'op': 'add', 'path': '/order/lines/-', 'value': _monitor},
          ]),
        ],
        (request) {
          // The state holds the agent's 40, so the user's 50 is not news.
          expect(request.reportedUserEdits, isEmpty);
          return const [AgentStep.say('OK.')];
        },
      ]);
      final host = MemoryStateHost(
        const OrderDraft(
          lines: [OrderLine(sku: 'HDMI-2M', quantity: 40, unitPrice: 8.55)],
        ),
      );
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      final sending = session.send('And 12 monitors');
      await pumpEventQueue();
      host.update((draft) => draft.withQuantity(0, 50));
      typed.complete();
      await sending;

      // Lines are addressed by index, so the agent's list is taken whole.
      expect(host.state, _twoLines);
      expect(session.view.marks.has('lines/1/sku'), isTrue);
      // The agent put back 40 over the user's 50: it wrote that leaf last.
      expect(session.view.marks.has('lines/0/quantity'), isTrue);
      expect(session.view.marks.has('lines/0/sku'), isFalse);

      await session.send('Thanks');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('an agent change of a list item merges with the user edit of '
        'another item', () async {
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(typed.future),
          const AgentStep.patchState([
            {'op': 'replace', 'path': '/order/lines/1/quantity', 'value': 15},
          ]),
        ],
      ]);
      final host = MemoryStateHost(_twoLines);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      final sending = session.send('15 monitors');
      await pumpEventQueue();
      host.update((draft) => draft.withQuantity(0, 50));
      typed.complete();
      await sending;

      expect(host.state.lines.map((line) => line.quantity), [50, 15]);
      expect(session.view.marks.paths, {'lines/1/quantity'});
      await session.dispose();
    });

    test('an agent change whose place the user removed is dropped and '
        'reported', () async {
      final typed = Completer<void>();
      final agent = ScriptedAgent([
        (_) => [
          AgentStep.waitFor(typed.future),
          const AgentStep.patchState([
            {'op': 'replace', 'path': '/order/lines/1/quantity', 'value': 15},
          ]),
        ],
      ]);
      final diagnostics = <TandemDiagnostic>[];
      final host = MemoryStateHost(_twoLines);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: TandemOptions(onDiagnostic: diagnostics.add),
      );

      final sending = session.send('15 monitors');
      await pumpEventQueue();
      host.update((draft) => draft.copyWith(lines: [draft.lines.first]));
      typed.complete();
      await sending;

      expect(host.state.lines.map((line) => line.sku), ['HDMI-2M']);
      expect(session.view.marks.paths, isEmpty);
      expect(
        diagnostics.map((diagnostic) => diagnostic.message),
        contains(contains('/order/lines/1/quantity')),
      );
      await session.dispose();
    });
  });

  group('Echoes and user edits', () {
    test('restating the state is no write', () async {
      final agent = ScriptedAgent([
        (request) => [
          AgentStep.setState(request.state),
          const AgentStep.say('Nothing to change.'),
        ],
      ]);
      final host = RecordingHost(_twoLines);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Check the order');

      expect(host.writes, isEmpty);
      expect(session.view.marks.paths, isEmpty);
      await session.dispose();
    });

    test('two agent deltas in one run into an asynchronous host are no user '
        'edit', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.patchState([
            {'op': 'replace', 'path': '/order/customer', 'value': _acme},
          ]),
          AgentStep.patchState([
            {'op': 'add', 'path': '/order/lines/-', 'value': _hdmi},
          ]),
          AgentStep.say('Filled in.'),
        ],
        (request) {
          expect(request.reportedUserEdits, isEmpty);
          return const [AgentStep.say('OK.')];
        },
      ]);
      final host = AsyncHost(OrderDraft.empty);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Order for Acme');
      await pumpEventQueue();

      // The final snapshot restates what the agent wrote: no third write.
      expect(host.writes, hasLength(2));
      expect(session.view.marks.has('customer/name'), isTrue);
      expect(session.view.marks.has('lines/0/sku'), isTrue);

      await session.send('Go on');
      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });

    test('two agent changes that reach an asynchronous host before its '
        'first echo are no user edit', () async {
      final host = AsyncHost(OrderDraft.empty);
      final connection = ManualConnection([
        (_) => _burst([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {
            'type': 'STATE_DELTA',
            'delta': [
              {'op': 'add', 'path': '/order', 'value': _orderJson()},
            ],
          },
          {
            'type': 'STATE_DELTA',
            'delta': [
              {
                'op': 'add',
                'path': '/order',
                'value': _orderJson(lines: [_hdmi]),
              },
            ],
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
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Order for Acme');
      await pumpEventQueue();

      expect(host.writes, hasLength(2));
      expect(host.state.lines.single.sku, 'HDMI-2M');
      expect(session.view.marks.has('customer'), isTrue);
      expect(session.view.marks.has('lines/0/quantity'), isTrue);

      await session.send('Go on');
      expect(_reportedEdits(connection.inputs.last), isEmpty);
      await session.dispose();
    });

    test(
      'a user edit is reported once, as JSON Pointers into the state',
      () async {
        final agent = ScriptedAgent([
          (request) {
            expect(request.reportedUserEdits, isEmpty);
            return const [AgentStep.say('Two lines.')];
          },
          (request) {
            expect(request.reportedUserEdits, [
              '/order/lines/1/quantity',
              '/order/notes',
            ]);
            return const [AgentStep.say('Recalculated.')];
          },
          (request) {
            expect(request.reportedUserEdits, isEmpty);
            return const [AgentStep.say('OK.')];
          },
        ]);
        final host = MemoryStateHost(_twoLines);
        final session = TandemSession(
          connection: agent,
          host: host,
          codec: orderCodec,
          options: quiet,
        );

        await session.send('Price the order');
        host
          ..update((draft) => draft.withQuantity(1, 15))
          ..update((draft) => draft.copyWith(notes: 'Urgent'))
          ..update((draft) => draft.withQuantity(1, 16));
        await session.send('I changed the monitors');
        await session.send('Thanks');

        expect(agent.isExhausted, isTrue);
        expect(session.view.error, isNull);
        await session.dispose();
      },
    );

    test('an edit an asynchronous host has not delivered when the run '
        'starts is reported in that run, once', () async {
      final agent = ScriptedAgent([
        (request) {
          expect(request.reportedUserEdits, [
            '/order/lines/1/quantity',
            '/order/notes',
          ]);
          return const [AgentStep.say('Recalculated.')];
        },
        (request) {
          expect(request.reportedUserEdits, isEmpty);
          return const [AgentStep.say('OK.')];
        },
      ]);
      final host = AsyncHost(_twoLines);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      // As a button handler would: two edits, then send, in one go.
      host
        ..update((draft) => draft.withQuantity(1, 15))
        ..update((draft) => draft.copyWith(notes: 'Urgent'));
      await session.send('Recalculate');
      await session.send('Thanks');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('without reportUserEdits, no edits are sent', () async {
      final agent = ScriptedAgent([
        (_) => const [AgentStep.say('Two lines.')],
        (request) {
          expect(request.reportedUserEdits, isEmpty);
          expect(request.input.context, isEmpty);
          return const [AgentStep.say('OK.')];
        },
      ]);
      final host = MemoryStateHost(_twoLines);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: TandemOptions(reportUserEdits: false, onDiagnostic: (_) {}),
      );

      await session.send('Price the order');
      host.update((draft) => draft.withQuantity(1, 15));
      await session.send('I changed the monitors');

      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });

    test(
      'a change of a field the codec does not share is no user edit',
      () async {
        final agent = ScriptedAgent([
          (_) => const [AgentStep.say('Two lines.')],
          (request) {
            expect(request.reportedUserEdits, isEmpty);
            return const [AgentStep.say('OK.')];
          },
        ]);
        final host = MemoryStateHost(const ScreenState(_twoLines));
        final session = TandemSession(
          connection: agent,
          host: host,
          codec: _screenCodec,
          options: quiet,
        );

        await session.send('Price the order');
        host.update((state) => ScreenState(state.draft, isSaving: true));
        await session.send('Saving');

        expect(agent.isExhausted, isTrue);
        await session.dispose();
      },
    );

    test(
      'the run sends the state of the codec keys and never server keys',
      () async {
        final agent = ScriptedAgent([
          (request) {
            expect(request.state.keys, ['order']);
            return const [AgentStep.say('Hello.')];
          },
          (request) {
            // The previous run ended with ag-ui-adk's snapshot with
            // `_ag_ui_*` keys and `pending_tool_calls`.
            expect(request.state.keys, ['order']);
            return const [AgentStep.say('Again.')];
          },
        ]);
        final session = TandemSession(
          connection: agent,
          host: MemoryStateHost(OrderDraft.empty),
          codec: orderCodec,
          options: quiet,
        );

        await session.send('Hello');
        await session.send('Again');

        expect(agent.isExhausted, isTrue);
        await session.dispose();
      },
    );

    test('agent state the codec cannot decode keeps the current value and is '
        'reported', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.setState({'order': 'not an order'}),
          AgentStep.say('Oops.'),
        ],
      ]);
      final diagnostics = <TandemDiagnostic>[];
      final host = RecordingHost(_twoLines);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: TandemOptions(onDiagnostic: diagnostics.add),
      );

      await session.send('Price the order');

      expect(host.writes, isEmpty);
      expect(host.state, _twoLines);
      expect(diagnostics.single.message, contains('could not decode'));
      expect(diagnostics.single.detail, isA<FormatException>());
      expect(session.view.error, isNull);
      expect(_lastAgentText(session), 'Oops.');
      await session.dispose();
    });
  });

  group('Agent marks', () {
    test(
      'mark the leaves the agent wrote; isLatest only its latest change',
      () async {
        final agent = ScriptedAgent([
          (_) => const [
            AgentStep.patchState([
              {'op': 'replace', 'path': '/order/customer', 'value': _acme},
            ]),
            AgentStep.patchState([
              {'op': 'add', 'path': '/order/lines/-', 'value': _hdmi},
            ]),
          ],
        ]);
        final session = TandemSession(
          connection: agent,
          host: MemoryStateHost(OrderDraft.empty),
          codec: orderCodec,
          options: quiet,
        );

        await session.send('Order for Acme');

        final marks = session.view.marks;
        expect(marks.paths, {
          'customer/id',
          'customer/name',
          'lines/0/sku',
          'lines/0/quantity',
          'lines/0/unitPrice',
        });
        expect(marks.has('customer'), isTrue);
        expect(marks.has('lines'), isTrue);
        expect(marks.has(''), isTrue);
        expect(marks.has('notes'), isFalse);
        expect(marks.isLatest('lines/0/quantity'), isTrue);
        expect(marks.isLatest('customer'), isFalse);
        await session.dispose();
      },
    );

    test('a user edit clears the marks of the edited leaves only', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.patchState([
            {'op': 'replace', 'path': '/order/customer', 'value': _acme},
            {'op': 'add', 'path': '/order/lines/-', 'value': _hdmi},
          ]),
        ],
      ]);
      final host = MemoryStateHost(OrderDraft.empty);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      await session.send('Order for Acme');
      host.update((draft) => draft.withQuantity(0, 50));

      final marks = session.view.marks;
      expect(marks.has('lines/0/quantity'), isFalse);
      expect(marks.isLatest('lines/0/quantity'), isFalse);
      expect(marks.has('lines/0/sku'), isTrue);
      expect(marks.has('customer/name'), isTrue);
      await session.dispose();
    });

    test('a value the codec does not take as the agent wrote it is not '
        'marked', () async {
      // The screen never lets the agent set a quantity above 100.
      final capped = StateCodec<OrderDraft>.json('order', (json) {
        final draft = OrderDraft.fromJson(json);
        return draft.copyWith(
          lines: [
            for (final line in draft.lines)
              if (line.quantity > 100) line.copyWith(quantity: 100) else line,
          ],
        );
      }, toJson: (draft) => draft.toJson());
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.patchState([
            {
              'op': 'add',
              'path': '/order/lines/-',
              'value': {'sku': 'HDMI-2M', 'quantity': 400, 'unitPrice': 8.55},
            },
          ]),
        ],
      ]);
      final host = MemoryStateHost(OrderDraft.empty);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: capped,
        options: quiet,
      );

      await session.send('400 cables');

      expect(host.state.lines.single.quantity, 100);
      expect(session.view.marks.has('lines/0/sku'), isTrue);
      expect(session.view.marks.has('lines/0/quantity'), isFalse);
      await session.dispose();
    });

    test('a leaf a listener of a synchronous host changes while the agent '
        'writes it is not marked', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.patchState([
            {
              'op': 'add',
              'path': '/order/lines/-',
              'value': {'sku': 'HDMI-2M', 'quantity': 400, 'unitPrice': 8.55},
            },
          ]),
        ],
        (request) {
          // The app, not the agent, put in 100.
          expect(request.reportedUserEdits, ['/order/lines/0/quantity']);
          return const [AgentStep.say('OK.')];
        },
      ]);
      final host = MemoryStateHost(OrderDraft.empty);
      // The screen never takes a quantity above 100, as a validating
      // listener would.
      host.stream.listen((draft) {
        if (draft.lines.isNotEmpty && draft.lines.first.quantity > 100) {
          host.update((current) => current.withQuantity(0, 100));
        }
      });
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        options: quiet,
      );

      await session.send('400 cables');

      expect(host.state.lines.single.quantity, 100);
      expect(session.view.marks.has('lines/0/sku'), isTrue);
      expect(session.view.marks.has('lines/0/quantity'), isFalse);

      await session.send('Thanks');

      expect(agent.isExhausted, isTrue);
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test(
      'a custom codec owns several keys; its paths start with the key',
      () async {
        final codec = StateCodec<ScreenState>.custom(
          keys: {'order', 'ui'},
          encode: (state) => {
            'order': state.draft.toJson(),
            'ui': {'isSaving': state.isSaving},
          },
          decode: (current, document) => ScreenState(
            OrderDraft.fromJson(document['order']! as Map<String, Object?>),
            isSaving:
                (document['ui']! as Map<String, Object?>)['isSaving']! as bool,
          ),
        );
        final agent = ScriptedAgent([
          (request) {
            expect(request.state, {
              'order': OrderDraft.empty.toJson(),
              'ui': {'isSaving': false},
            });
            return const [
              AgentStep.patchState([
                {'op': 'replace', 'path': '/ui/isSaving', 'value': true},
                {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
              ]),
            ];
          },
        ]);
        final host = MemoryStateHost(const ScreenState(OrderDraft.empty));
        final session = TandemSession(
          connection: agent,
          host: host,
          codec: codec,
          options: quiet,
        );

        await session.send('Save it, urgent');

        expect(host.state.isSaving, isTrue);
        expect(host.state.draft.notes, 'Urgent');
        expect(session.view.marks.paths, {'ui/isSaving', 'order/notes'});
        await session.dispose();
      },
    );

    test('a lens codec writes the shared draft and keeps the rest of the '
        'state', () async {
      final agent = ScriptedAgent([
        (request) {
          expect(request.state, {'order': _twoLines.toJson()});
          return const [
            AgentStep.patchState([
              {'op': 'replace', 'path': '/order/notes', 'value': 'Urgent'},
            ]),
          ];
        },
      ]);
      final host = MemoryStateHost(
        const ScreenState(_twoLines, isSaving: true),
      );
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: _screenCodec,
        options: quiet,
      );

      await session.send('Urgent');

      expect(host.state.draft.notes, 'Urgent');
      expect(host.state.isSaving, isTrue);
      expect(session.view.marks.paths, {'notes'});
      await session.dispose();
    });
  });

  group('StateCodec', () {
    test('json encodes the model under its key and decodes it back', () {
      expect(orderCodec.keys, {'order'});
      expect(orderCodec.encode(_twoLines), {'order': _twoLines.toJson()});
      expect(
        orderCodec.decode(OrderDraft.empty, {
          'order': _twoLines.toJson(),
          '_ag_ui_thread_id': 't',
        }),
        _twoLines,
      );
    });

    test('decoding a document without the model throws a FormatException', () {
      expect(
        () => orderCodec.decode(OrderDraft.empty, const {}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('"order"'),
          ),
        ),
      );
      expect(
        () => orderCodec.decode(OrderDraft.empty, const {'order': 3}),
        throwsFormatException,
      );
    });

    test('lens keeps what it does not share', () {
      const state = ScreenState(OrderDraft.empty, isSaving: true);
      final decoded = _screenCodec.decode(state, {'order': _twoLines.toJson()});
      expect(decoded, const ScreenState(_twoLines, isSaving: true));
      expect(_screenCodec.encode(state), {'order': OrderDraft.empty.toJson()});
    });
  });

  group('MemoryStateHost', () {
    test('delivers every new value synchronously, and nothing for an equal '
        'value', () {
      final host = StateHost.memory(1);
      final values = <int>[];
      host.stream.listen(values.add);

      (host as MemoryStateHost<int>).update((value) => value + 1);
      expect(values, [2]);
      host
        ..writeFromAgent(2)
        ..writeFromAgent(5);
      expect(values, [2, 5]);
      expect(host.state, 5);
    });

    test('delivers a value written by a listener after the current one', () {
      final host = MemoryStateHost(0);
      final values = <int>[];
      host.stream.listen((value) {
        if (value == 1) {
          host.update((value) => value + 1);
        }
      });
      host.stream.listen(values.add);

      host.update((_) => 1);

      expect(values, [1, 2]);
      expect(host.state, 2);
    });
  });
}

final _screenCodec = StateCodec.lens<ScreenState, OrderDraft>(
  'order',
  get: (state) => state.draft,
  set: (state, draft) => ScreenState(draft, isSaving: state.isSaving),
  fromJson: OrderDraft.fromJson,
  toJson: (draft) => draft.toJson(),
);

Map<String, Object?> _orderJson({
  List<Map<String, Object?>> lines = const [],
}) => {'customer': _acme, 'lines': lines, 'notes': ''};

List<String> _reportedEdits(RunInput input) =>
    RunRequest(input).reportedUserEdits;

String? _lastAgentText(TandemSession<Object?> session) =>
    session.view.timeline.whereType<AgentMessage>().lastOrNull?.text;

/// [events] delivered in one go, in one microtask, as an adapter does when
/// one network chunk holds several frames.
Stream<WireEvent> _burst(List<Map<String, Object?>> events) {
  late final StreamController<WireEvent> controller;
  controller = StreamController(
    sync: true,
    onListen: () => scheduleMicrotask(() {
      for (final event in events) {
        controller.add(WireEvent.fromJson(event));
      }
      unawaited(controller.close());
    }),
  );
  return controller.stream;
}
