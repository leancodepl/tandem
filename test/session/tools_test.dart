// The app's tools: their JSON Schema, name rules, argument checks before
// they run, typed argument reads, failures, results and timeline labels.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'support.dart';

const _lineParams = {
  'sku': Param.string('The product'),
  'quantity': Param.integer('How many'),
  'unit': Param.string('The unit', optional: true, oneOf: ['pcs', 'box']),
};

const _orderParams = {
  'customerId': Param.string('The customer'),
  'lines': Param.list(Param.object(_lineParams, 'One line'), 'The lines'),
  'discount': Param.number('Percent', optional: true),
  'express': Param.boolean('Express delivery', optional: true),
};

void main() {
  group('Param', () {
    test('becomes JSON Schema without additionalProperties', () {
      final schema = const Param.object(
        _orderParams,
        'An order',
      ).toJsonSchema();

      expect(schema, {
        'type': 'object',
        'description': 'An order',
        'properties': {
          'customerId': {'type': 'string', 'description': 'The customer'},
          'lines': {
            'type': 'array',
            'description': 'The lines',
            'items': {
              'type': 'object',
              'description': 'One line',
              'properties': {
                'sku': {'type': 'string', 'description': 'The product'},
                'quantity': {'type': 'integer', 'description': 'How many'},
                'unit': {
                  'type': 'string',
                  'description': 'The unit',
                  'enum': ['pcs', 'box'],
                },
              },
              'required': ['sku', 'quantity'],
            },
          },
          'discount': {'type': 'number', 'description': 'Percent'},
          'express': {'type': 'boolean', 'description': 'Express delivery'},
        },
        'required': ['customerId', 'lines'],
      });
      expect(jsonEncode(schema), isNot(contains('additionalProperties')));
    });

    test('an object without required fields has no "required"', () {
      expect(
        const Param.object({
          'note': Param.string('A note', optional: true),
        }, 'Extras').toJsonSchema(),
        {
          'type': 'object',
          'description': 'Extras',
          'properties': {
            'note': {'type': 'string', 'description': 'A note'},
          },
        },
      );
    });

    test("a tool's parameters are sent as an object schema", () async {
      final agent = ScriptedAgent([
        (request) {
          expect(request.input.tools.map((tool) => tool.toJson()), [
            {
              'name': 'place_order',
              'description': 'Place it.',
              'parameters': {
                'type': 'object',
                'properties': {
                  for (final MapEntry(:key, :value) in _orderParams.entries)
                    key: value.toJsonSchema(),
                },
                'required': ['customerId', 'lines'],
              },
            },
            {
              'name': 'refresh',
              'description': 'Refresh.',
              'parameters': {
                'type': 'object',
                'properties': <String, Object?>{},
              },
            },
          ]);
          return const [];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [
          Tool(
            'place_order',
            'Place it.',
            params: _orderParams,
            run: (_) => null,
          ),
          Tool('refresh', 'Refresh.', run: (_) => null),
        ],
        options: quiet,
      );

      await session.send('Hi');

      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });
  });

  group('Tool names', () {
    TandemSession<OrderDraft> withTools(List<String> names) => TandemSession(
      connection: ScriptedAgent(const []),
      host: MemoryStateHost(OrderDraft.empty),
      codec: orderCodec,
      tools: [
        for (final name in names) Tool(name, 'A tool.', run: (_) => null),
      ],
      options: quiet,
    );

    test('match [a-zA-Z0-9_-]{1,64}', () async {
      final session = withTools(['search_catalog', 'Get-Price2', 'a' * 64]);
      await session.dispose();

      for (final name in ['', 'search catalog', 'zamów', 'a' * 65, 'a.b']) {
        expect(
          () => withTools([name]),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.invalidValue,
              'invalidValue',
              name,
            ),
          ),
          reason: name,
        );
      }
    });

    test('are unique', () {
      expect(
        () => withTools(['search_catalog', 'search_catalog']),
        throwsArgumentError,
      );
    });
  });

  group('Arguments', () {
    /// Runs one call of `place_order` with [args] and returns what the agent
    /// got back.
    Future<({Map<String, Object?>? answer, int runs, TandemView view})> call(
      Map<String, Object?> args, {
      bool needsApproval = false,
    }) async {
      final place = RecordingTool(
        'place_order',
        params: _orderParams,
        needsApproval: needsApproval,
        result: 'placed',
      );
      Map<String, Object?>? answer;
      final agent = ScriptedAgent([
        (_) => [AgentStep.callTool('place_order', args)],
        (request) {
          answer = request.resultOf('place_order');
          return const [AgentStep.say('Fixed it.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [place.tool],
        options: quiet,
      );
      await session.send('Place it');
      final view = session.view;
      await session.dispose();
      return (answer: answer, runs: place.calls.length, view: view);
    }

    const valid = {
      'customerId': 'C-17',
      'lines': [
        {'sku': 'HDMI-2M', 'quantity': 40.0, 'unit': 'pcs'},
      ],
      'discount': 5,
      'note': 'Arguments the tool does not declare are fine.',
    };

    test('that match the params reach the tool', () async {
      final result = await call(valid);

      expect(result.runs, 1);
      expect(result.answer, {'status': 'ok', 'result': 'placed'});
    });

    for (final (description, args, error) in [
      (
        'a missing argument',
        {'lines': <Object?>[]},
        'Invalid argument "customerId": is missing',
      ),
      (
        'null for a required argument',
        {'customerId': null, 'lines': <Object?>[]},
        'Invalid argument "customerId": must not be null',
      ),
      (
        'a string for a number',
        {...valid, 'discount': '5%'},
        'Invalid argument "discount": must be a number, not a string',
      ),
      (
        'a fraction for a whole number',
        {
          ...valid,
          'lines': [
            {'sku': 'HDMI-2M', 'quantity': 2.5},
          ],
        },
        'Invalid argument "lines[0].quantity": must be a whole number, not a '
            'number',
      ),
      (
        'a value outside oneOf',
        {
          ...valid,
          'lines': [
            {'sku': 'HDMI-2M', 'quantity': 1, 'unit': 'kg'},
          ],
        },
        'Invalid argument "lines[0].unit": must be one of "pcs", "box", not '
            '"kg"',
      ),
      (
        'an object for a list',
        {...valid, 'lines': <String, Object?>{}},
        'Invalid argument "lines": must be a list, not an object',
      ),
      (
        'a list item that is not an object',
        {
          ...valid,
          'lines': ['HDMI-2M'],
        },
        'Invalid argument "lines[0]": must be an object, not a string',
      ),
      (
        'a string for a boolean',
        {...valid, 'express': 'yes'},
        'Invalid argument "express": must be true or false, not a string',
      ),
    ]) {
      test(
        '$description go back to the agent; the tool does not run',
        () async {
          final result = await call(args);

          expect(result.runs, 0);
          expect(result.answer, {'status': 'error', 'error': error});
          final activity = result.view.timeline
              .whereType<ToolActivity>()
              .single;
          expect(activity.status, ToolActivityStatus.failed);
          expect(result.view.error, isNull);
        },
      );
    }

    test('that do not match a tool with approval go back at once, without '
        'a request', () async {
      final result = await call({'lines': <Object?>[]}, needsApproval: true);

      expect(result.runs, 0);
      expect(result.answer?['status'], 'error');
      expect(result.view.openApprovals, isEmpty);
      expect(result.view.timeline.whereType<ApprovalRequest>(), isEmpty);
    });

    test('that are not a JSON object go back to the agent', () async {
      final place = RecordingTool('place_order');
      final connection = ManualConnection([
        (_) => events([
          {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r1'},
          {
            'type': 'TOOL_CALL_START',
            'toolCallId': 'call-1',
            'toolCallName': 'place_order',
          },
          {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'call-1', 'delta': '[1, 2'},
          {'type': 'TOOL_CALL_END', 'toolCallId': 'call-1'},
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
        tools: [place.tool],
        options: quiet,
      );

      await session.send('Place it');

      expect(place.calls, isEmpty);
      final messages = connection.inputs.last.messages;
      final call = messages.whereType<WireAssistantMessage>().single;
      expect(call.toolCalls.single.arguments, '[1, 2');
      final answer = messages.whereType<WireToolMessage>().single;
      expect(jsonDecode(answer.content), {
        'status': 'error',
        'error':
            'Invalid argument "arguments": must be a JSON object, not '
            '[1, 2',
      });
      await session.dispose();
    });
  });

  group('ToolArgs', () {
    const args = ToolArgs({
      'query': 'HDMI',
      'quantity': 40.0,
      'price': 15,
      'express': true,
      'skus': ['HDMI-2M', 'MON-27'],
      'counts': [1, 2.0],
      'customer': {'id': 'C-17'},
      'lines': [
        {'sku': 'HDMI-2M', 'quantity': 40},
        {'sku': 'MON-27', 'quantity': 'twelve'},
      ],
      'note': null,
    });

    test('reads typed values; numbers are lenient', () {
      expect(args.read<String>('query'), 'HDMI');
      expect(args.read<int>('quantity'), 40);
      expect(args.read<double>('price'), 15.0);
      expect(args.read<num>('price'), 15);
      expect(args.read<bool>('express'), isTrue);
      expect(args.read<List<Object?>>('skus'), hasLength(2));
      expect(args.read<Map<String, Object?>>('customer'), {'id': 'C-17'});
      expect(args.read<String?>('note'), isNull);
      expect(args.readOrNull<String>('note'), isNull);
      expect(args.readOrNull<String>('missing'), isNull);
      expect(args.readList<String>('skus'), ['HDMI-2M', 'MON-27']);
      expect(args.readList<int>('counts'), [1, 2]);
      expect(args.object('customer').read<String>('id'), 'C-17');
      expect(args.objects('lines').first.read<int>('quantity'), 40);
    });

    test('throws ToolArgumentError naming the argument', () {
      void expectError(void Function() read, String argument, String message) =>
          expect(
            read,
            throwsA(
              isA<ToolArgumentError>()
                  .having((error) => error.argument, 'argument', argument)
                  .having((error) => error.message, 'message', message),
            ),
          );

      expectError(
        () => args.read<int>('query'),
        'query',
        'must be a whole '
            'number, not a string',
      );
      expectError(() => args.read<String>('missing'), 'missing', 'is missing');
      expectError(() => args.read<String>('note'), 'note', 'must not be null');
      expectError(
        () => args.objects('lines')[1].read<int>('quantity'),
        'lines[1].quantity',
        'must be a whole number, not a string',
      );
      expectError(
        () => args.readList<int>('skus'),
        'skus[0]',
        'must be a whole number, not a string',
      );
      expect(
        ToolArgumentError('quantity', 'is missing').toString(),
        'Invalid argument "quantity": is missing',
      );
    });

    test('a ToolArgumentError thrown in run goes back to the agent', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('search_catalog', {'limit': 'ten'}),
        ],
        (request) {
          expect(request.resultOf('search_catalog'), {
            'status': 'error',
            'error':
                'Invalid argument "limit": must be a whole number, not '
                'a string',
          });
          return const [AgentStep.say('Retrying.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [
          Tool(
            'search_catalog',
            'Search.',
            run: (call) => call.read<int>('limit'),
          ),
        ],
        options: quiet,
      );

      await session.send('Search');

      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });
  });

  group('Running tools', () {
    test('a tool that throws sends the error; the session goes on', () async {
      final search = RecordingTool(
        'search_catalog',
        error: const FormatException('Catalog is down'),
      );
      final agent = ScriptedAgent([
        (_) => const [AgentStep.callTool('search_catalog')],
        (request) {
          expect(request.resultOf('search_catalog'), {
            'status': 'error',
            'error': 'FormatException: Catalog is down',
          });
          return const [AgentStep.say('The catalog is down.')];
        },
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [search.tool],
        options: quiet,
      );

      await session.send('Search');

      expect(agent.isExhausted, isTrue);
      expect(
        session.view.timeline.whereType<ToolActivity>().single.status,
        ToolActivityStatus.failed,
      );
      expect(session.view.error, isNull);
      await session.dispose();
    });

    test('tools run one after another in call order, with the state when '
        'each starts', () async {
      final order = <String>[];
      final host = MemoryStateHost(OrderDraft.empty);
      Tool<OrderDraft> step(String name) => Tool(
        name,
        'A step.',
        run: (call) async {
          order.add('${call.toolName} starts with "${call.state.notes}"');
          await Future<void>.delayed(Duration.zero);
          host.update((draft) => draft.copyWith(notes: name));
          order.add('${call.toolName} ends');
          return null;
        },
      );
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.callTool('first'),
          AgentStep.callTool('second'),
        ],
        (_) => const [],
      ]);
      final session = TandemSession(
        connection: agent,
        host: host,
        codec: orderCodec,
        tools: [step('first'), step('second')],
        options: quiet,
      );

      await session.send('Go');

      expect(order, [
        'first starts with ""',
        'first ends',
        'second starts with "first"',
        'second ends',
      ]);
      expect(agent.isExhausted, isTrue);
      await session.dispose();
    });

    test(
      'a result that cannot be encoded is sent as text and reported',
      () async {
        final diagnostics = <TandemDiagnostic>[];
        final agent = ScriptedAgent([
          (_) => const [AgentStep.callTool('lookup')],
          (request) {
            expect(request.resultOf('lookup'), {
              'status': 'ok',
              'result': 'an opaque result',
            });
            return const [];
          },
        ]);
        final session = TandemSession(
          connection: agent,
          host: MemoryStateHost(OrderDraft.empty),
          codec: orderCodec,
          tools: [Tool('lookup', 'Look up.', run: (_) => const _Opaque())],
          options: TandemOptions(onDiagnostic: diagnostics.add),
        );

        await session.send('Look it up');

        expect(agent.isExhausted, isTrue);
        expect(diagnostics.single.message, contains('"lookup"'));
        await session.dispose();
      },
    );
  });

  group('Labels', () {
    test("are the tool's label, the agent tool's label, or the name in "
        'words', () async {
      final agent = ScriptedAgent([
        (_) => const [
          AgentStep.runAgentTool('find_customer'),
          AgentStep.runAgentTool('checkStock'),
          AgentStep.callTool('search_catalog'),
          AgentStep.callTool('price_lines'),
        ],
        (_) => const [],
      ]);
      final session = TandemSession(
        connection: agent,
        host: MemoryStateHost(OrderDraft.empty),
        codec: orderCodec,
        tools: [
          RecordingTool('search_catalog', label: 'Searching the catalog').tool,
          RecordingTool('price_lines').tool,
        ],
        options: TandemOptions(
          toolLabels: const {'find_customer': 'Looking up the customer'},
          onDiagnostic: (_) {},
        ),
      );

      await session.send('Go');

      expect(
        session.view.timeline.whereType<ToolActivity>().map(
          (activity) => (activity.label, activity.runsInApp),
        ),
        [
          ('Looking up the customer', false),
          ('Check stock', false),
          ('Searching the catalog', true),
          ('Price lines', true),
        ],
      );
      await session.dispose();
    });
  });
}

/// A result without `toJson()`.
final class _Opaque {
  const _Opaque();

  @override
  String toString() => 'an opaque result';
}
