import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

AgentConnection orderDeskAgent() => ScriptedAgent.repeating((raw) {
  final request = AgentRequest(raw);
  if (request.isUserMessage) {
    if (request.newNotes.lastOrNull case {
      'pressed': 'place_order',
      'result': final id,
    }) {
      return [AgentStep.say('You placed order $id from the summary.')];
    }
    if (request.offersTool('set_quantity')) {
      if (request.context('order') case {'lines': []}) {
        return const [
          AgentStep.callTool('set_customer', {'customerId': 'acme'}),
          AgentStep.callTool('set_quantity', {
            'sku': 'VC-HDMI-2M',
            'quantity': 40,
          }),
          AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 12}),
          AgentStep.callTool('set_delivery', {
            'address': 'Magazynowa 5, 61-001 Poznań',
            'date': '2026-10-23',
          }),
          AgentStep.callTool('tandem_show_view', {
            'messages': orderSummaryView,
          }),
        ];
      }
      return request.offersTool('place_order')
          ? const [AgentStep.callTool('place_order')]
          : const [
              AgentStep.say(
                'Choose a customer and delivery before placing it.',
              ),
            ];
    }
    return const [AgentStep.say('This order is already placed.')];
  }
  final results = request.latestToolResults;
  final last = results.lastOrNull;
  return [
    AgentStep.say(switch ((_problem(results), last?.toolName)) {
      (final problem?, _) => problem,
      (null, 'place_order') => 'Order ${last?.value} placed.',
      _ =>
        'The order is ready, with a summary below it. Change quantities '
            'there or on the screen, then place the order.',
    }),
  ];
});

/// The summary the agent draws below the form: the lines with a button that
/// removes each, the total and a button that places the order.
const orderSummaryView = [
  {
    'version': 'v0.9.1',
    'createSurface': {
      'surfaceId': 'main',
      'catalogId': 'https://pub.dev/packages/tandem/a2ui/v0_9_1/catalog.json',
    },
  },
  {
    'version': 'v0.9.1',
    'updateComponents': {
      'surfaceId': 'main',
      'components': [
        {'id': 'root', 'component': 'Card', 'child': 'body'},
        {
          'id': 'body',
          'component': 'Column',
          'children': ['title', 'lines', 'line', 'total', 'place'],
        },
        {
          'id': 'title',
          'component': 'Text',
          'variant': 'h3',
          'text': {
            'call': 'formatString',
            'args': {'value': r'Summary for ${/order/customer/name}'},
            'returnType': 'string',
          },
        },
        {
          'id': 'lines',
          'component': 'List',
          'children': {'componentId': 'order_line', 'path': '/order/lines'},
        },
        {
          'id': 'order_line',
          'component': 'Row',
          'children': ['details', 'remove'],
        },
        {
          'id': 'details',
          'component': 'Column',
          'children': ['name', 'amount'],
        },
        {
          'id': 'name',
          'component': 'Text',
          'text': {'path': 'name'},
        },
        {
          'id': 'amount',
          'component': 'Text',
          'variant': 'caption',
          'text': {
            'call': 'formatString',
            'args': {'value': r'${quantity} pcs · ${lineTotal}'},
            'returnType': 'string',
          },
        },
        {
          'id': 'remove',
          'component': 'Button',
          'child': 'remove_label',
          'variant': 'borderless',
          'action': {
            'event': {
              'name': 'set_quantity',
              'context': {
                'sku': {'path': 'sku'},
                'quantity': 0,
              },
            },
          },
        },
        {'id': 'remove_label', 'component': 'Text', 'text': 'Remove'},
        {'id': 'line', 'component': 'Divider'},
        {
          'id': 'total',
          'component': 'Text',
          'variant': 'h3',
          'text': {
            'call': 'formatString',
            'args': {'value': r'Total: ${/order/total}'},
            'returnType': 'string',
          },
        },
        {
          'id': 'place',
          'component': 'Button',
          'child': 'place_label',
          'variant': 'primary',
          'action': {
            'event': {'name': 'place_order'},
          },
        },
        {'id': 'place_label', 'component': 'Text', 'text': 'Place order'},
      ],
    },
  },
];

String? _problem(List<AgentToolResult> results) {
  // This script's app calls return null or an id; objects are control answers.
  for (final result in results.reversed) {
    if (result.value case {'status': final String status}) {
      final problem = switch (status) {
        'shown' => null,
        'rejected_by_user' => 'You rejected the action. It did not run.',
        'invalidated' =>
          'What I saw changed. Ask again to use the current values.',
        'cancelled' =>
          'The action was cancelled. Ask again when you are ready.',
        _ =>
          'The action did not go through. '
              'Check the screen before trying again.',
      };
      if (problem != null) {
        return problem;
      }
    }
  }
  return null;
}
