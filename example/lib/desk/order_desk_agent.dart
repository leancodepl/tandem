import 'dart:convert';

import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

AgentConnection orderDeskAgent() => _DemoAgent((request) {
  if (!request.isUser) {
    return [
      AgentStep.say(switch ((request.problem, request.lastTool)) {
        (final problem?, _) => problem,
        (null, 'place_order') => 'Order ${request.lastResult} placed.',
        _ =>
          'The order is ready, with a summary below it. Change quantities '
              'there or on the screen, then place the order.',
      }),
    ];
  }
  if (request.newPress case {'pressed': 'place_order', 'result': final id}) {
    return [AgentStep.say('You placed order $id from the summary.')];
  }
  if (!request.lists('set_quantity')) {
    return const [AgentStep.say('This order is already placed.')];
  }
  if (request.order case {'lines': []}) {
    return const [
      AgentStep.callTool('set_customer', {'customerId': 'acme'}),
      AgentStep.callTool('set_quantity', {'sku': 'VC-HDMI-2M', 'quantity': 40}),
      AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 12}),
      AgentStep.callTool('set_delivery', {
        'address': 'Magazynowa 5, 61-001 Poznań',
        'date': '2026-10-23',
      }),
      AgentStep.callTool('tandem_show_view', {'messages': orderSummaryView}),
    ];
  }
  return request.lists('place_order')
      ? const [AgentStep.callTool('place_order')]
      : const [
          AgentStep.say('Choose a customer and delivery before placing it.'),
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

/// Plays [turn] in every run, unlike a [ScriptedAgent], which fails past
/// its script.
final class _DemoAgent(final AgentTurn turn) implements AgentConnection {
  final _turns = <AgentTurn>[];
  late final _agent = ScriptedAgent(_turns);

  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) {
    _turns.add(turn);
    return _agent.run(input);
  }
}

/// What the script reads from the body of a run.
extension on Map<String, Object?> {
  List<Map<String, Object?>> get _messages => switch (this) {
    {'messages': final List<Object?> messages} => messages.cast(),
    _ => const [],
  };

  bool get isUser => _messages.lastOrNull?['role'] == 'user';

  /// The decoded value of the `context` entry [name].
  Object? _context(String name) => switch (this) {
    {'context': final List<Object?> entries} => [
      for (final entry in entries)
        if (entry
            case {
              'description': final String description,
              'value': final String value,
            }
            when description.startsWith('$name:'))
          jsonDecode(value),
    ].firstOrNull,
    _ => null,
  };

  Object? get order => _context('order');

  /// The latest press in the agent's view since its last turn.
  Object? get newPress => switch (_context('app_notes')) {
    {'new': final List<Object?> notes} => notes.lastOrNull,
    _ => null,
  };

  bool lists(String tool) => switch (this) {
    {'tools': final List<Object?> tools} => tools.any(
      (listed) => listed is Map && listed['name'] == tool,
    ),
    _ => false,
  };

  /// The method that the last message answers.
  String? get lastTool {
    final answered = _messages.lastOrNull?['toolCallId'];

    return [
      for (final message in _messages)
        if (message['toolCalls'] case final List<Object?> calls)
          for (final call in calls)
            if (call
                case {'id': final id, 'function': {'name': final String name}}
                when id == answered)
              name,
    ].lastOrNull;
  }

  Object? get lastResult => switch (_messages.lastOrNull) {
    {'role': 'tool', 'content': final String content} => jsonDecode(content),
    _ => null,
  };

  /// What kept a call of the last turn from running, in the agent's words.
  String? get problem => [
    for (final answer in _messages.reversed.takeWhile(_isAnswer))
      if (answer case {'content': final String content})
        if (jsonDecode(content) case {'status': final String status})
          ?switch (status) {
            'shown' => null,
            'rejected_by_user' => 'You rejected the action. It did not run.',
            'invalidated' =>
              'What I saw changed. Ask again to use the current values.',
            'cancelled' =>
              'The action was cancelled. Ask again when you are ready.',
            _ =>
              'The action did not go through. '
                  'Check the screen before trying again.',
          },
  ].firstOrNull;
}

bool _isAnswer(Map<String, Object?> message) => message['role'] == 'tool';
