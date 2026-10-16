// The B2B order scenario of doc/design.md, through the public interface:
// agent tools that write the shared state, tools of the app with an
// automatic follow-up, and an order placed only after the user's approval.

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import 'support.dart';

const _email =
    '40 HDMI cables 2m for Acme, delivery Friday. Marta, Acme Sp. z o.o.';

const _acme = {'id': 'C-17', 'name': 'Acme Sp. z o.o.'};

const _catalogResult = [
  {'sku': 'HDMI-2M', 'name': 'HDMI cable 2m', 'listPrice': 9.5},
];

void main() {
  test('fills the order with the agent and places it after approval', () async {
    final catalog = RecordingTool(
      'search_catalog',
      params: {'query': const Param.string('For example "HDMI cable 2m"')},
      result: _catalogResult,
      label: 'Searching the catalog',
    );
    final prices = RecordingTool(
      'price_lines',
      params: {
        'customerId': const Param.string('The customer'),
        'skus': const Param.list(Param.string('A SKU'), 'The products'),
      },
      result: {'HDMI-2M': 8.55},
    );
    final placed = <OrderDraft>[];
    final placeOrder = Tool<OrderDraft>(
      'place_order',
      'Place the order exactly as it is on the screen.',
      needsApproval: true,
      run: (call) {
        placed.add(call.state);
        return {'number': 'ZAM/2026/0042'};
      },
    );
    final agent = ScriptedAgent([
      (request) {
        expect(request.userText, _email);
        expect(request.state, {'order': OrderDraft.empty.toJson()});
        expect(request.input.tools.map((tool) => tool.name), [
          'search_catalog',
          'price_lines',
          'place_order',
        ]);
        return const [
          AgentStep.runAgentTool(
            'find_customer',
            args: {'query': 'Acme'},
            result: _acme,
          ),
          AgentStep.patchState([
            {'op': 'replace', 'path': '/order/customer', 'value': _acme},
          ]),
          AgentStep.say('Acme it is. Looking up the cable and its price.'),
          AgentStep.callTool('search_catalog', {'query': 'HDMI cable 2m'}),
          AgentStep.callTool('price_lines', {
            'customerId': 'C-17',
            'skus': ['HDMI-2M'],
          }),
        ];
      },
      (request) {
        // The automatic follow-up carries both results.
        expect(request.userText, isNull);
        expect(request.resultOf('search_catalog'), {
          'status': 'ok',
          'result': _catalogResult,
        });
        expect(request.resultOf('price_lines'), {
          'status': 'ok',
          'result': {'HDMI-2M': 8.55},
        });
        return const [
          AgentStep.runAgentTool(
            'update_order',
            args: {'sku': 'HDMI-2M', 'quantity': 40},
            result: {'status': 'updated'},
          ),
          AgentStep.patchState([
            {
              'op': 'add',
              'path': '/order/lines/-',
              'value': {'sku': 'HDMI-2M', 'quantity': 40, 'unitPrice': 8.55},
            },
          ]),
          AgentStep.callTool('place_order'),
        ];
      },
      (request) {
        expect(request.resultOf('place_order'), {
          'status': 'executed',
          'approved': true,
          'result': {'number': 'ZAM/2026/0042'},
        });
        return const [AgentStep.say('Order ZAM/2026/0042 is placed.')];
      },
    ]);
    final diagnostics = <TandemDiagnostic>[];
    final host = MemoryStateHost(OrderDraft.empty);
    final session = TandemSession(
      connection: agent,
      host: host,
      codec: orderCodec,
      tools: [catalog.tool, prices.tool, placeOrder],
      options: TandemOptions(
        toolLabels: const {'find_customer': 'Looking up the customer'},
        onDiagnostic: diagnostics.add,
      ),
    );

    await session.send(_email);

    // The agent filled the draft and proposed placing it.
    expect(agent.requests, hasLength(2));
    expect(host.state.customer, Customer.fromJson(_acme));
    expect(host.state.lines, [
      const OrderLine(sku: 'HDMI-2M', quantity: 40, unitPrice: 8.55),
    ]);
    expect(catalog.calls.single.read<String>('query'), 'HDMI cable 2m');
    expect(prices.calls.single.readList<String>('skus'), ['HDMI-2M']);
    expect(session.view.isRunning, isFalse);
    expect(session.view.error, isNull);
    expect(session.view.marks.has('customer/name'), isTrue);
    expect(session.view.marks.has('lines/0/quantity'), isTrue);
    expect(session.view.marks.isLatest('lines/0'), isTrue);
    expect(session.view.marks.isLatest('customer'), isFalse);
    expect(session.view.marks.has('notes'), isFalse);
    final request = session.view.openApprovals.single;
    expect(request.toolName, 'place_order');
    expect(request.label, 'Place order');
    expect(request.status, ApprovalStatus.pending);
    expect(request.canApprove, isTrue);
    expect(request.args.json, isEmpty);
    expect(placed, isEmpty);

    await request.approve();

    expect(placed, [host.state]);
    await pumpEventQueue();

    expect(agent.isExhausted, isTrue);
    expect(session.view.isRunning, isFalse);
    expect(session.view.openApprovals, isEmpty);
    expect(session.view.error, isNull);
    expect(diagnostics, isEmpty);
    expect(_describe(session.view.timeline), [
      'user: $_email',
      'agent tool Looking up the customer: succeeded',
      'agent: Acme it is. Looking up the cable and its price.',
      'tool Searching the catalog: succeeded',
      'tool Price lines: succeeded',
      'agent tool Update order: succeeded',
      'approval Place order: executed',
      'agent: Order ZAM/2026/0042 is placed.',
    ]);
    final executed = session.view.timeline.whereType<ApprovalRequest>().single;
    expect(executed.result, {'number': 'ZAM/2026/0042'});
    expect(executed.canApprove, isFalse);
    expect(executed.canReject, isFalse);

    await session.dispose();
  });
}

/// The timeline as short lines, for one readable expectation.
List<String> _describe(List<TimelineItem> timeline) => [
  for (final item in timeline)
    switch (item) {
      UserMessage(:final text, :final isQueued) =>
        'user${isQueued ? ' (queued)' : ''}: $text',
      AgentMessage(:final text, :final isStreaming) =>
        'agent${isStreaming ? ' (streaming)' : ''}: $text',
      ToolActivity(:final label, :final status, :final runsInApp) =>
        '${runsInApp ? 'tool' : 'agent tool'} $label: ${status.name}',
      ApprovalRequest(:final label, :final status) =>
        'approval $label: ${status.name}',
    },
];
