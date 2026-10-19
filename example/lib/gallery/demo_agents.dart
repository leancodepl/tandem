import 'package:example/gallery/demo_request.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

AgentConnection orderDeskAgent() => _DemoAgent((request) {
  if (!request.isUser) {
    return [
      AgentStep.say(switch ((request.problem, request.lastTool)) {
        (final problem?, _) => problem,
        (null, 'place_order') => 'Order ${request.lastResult} placed.',
        _ =>
          'The order is ready. Change quantities on the screen, '
              'then ask me to place the order.',
      }),
    ];
  }
  if (!request.lists('set_quantity')) {
    return const [AgentStep.say('This order is already placed.')];
  }
  if (request.view case {'lines': []}) {
    return const [
      AgentStep.callTool('set_customer', {'customerId': 'acme'}),
      AgentStep.callTool('set_quantity', {'sku': 'VC-HDMI-2M', 'quantity': 40}),
      AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 12}),
      AgentStep.callTool('set_delivery', {
        'address': 'Magazynowa 5, 61-001 Poznań',
        'date': '2026-10-23',
      }),
    ];
  }
  return request.lists('place_order')
      ? const [AgentStep.callTool('place_order')]
      : const [
          AgentStep.say('Choose a customer and delivery before placing it.'),
        ];
});

AgentConnection shoppingListAgent() => _listAgent(
  items: const ['Milk', 'Bread'],
  argument: 'item',
  action: 'clear',
  done: 'The shopping list is empty.',
);

AgentConnection cartAgent() => _listAgent(
  items: const ['Keyboard', 'USB-C cable'],
  argument: 'item',
  action: 'checkout',
  done: 'Checkout complete. The cart is empty.',
);

AgentConnection todoAgent() => _listAgent(
  items: const ['Review the release', 'Update the changelog'],
  argument: 'todo',
  action: 'clear',
  done: 'The to-do list is empty.',
);

AgentConnection contactAgent() => _DemoAgent(
  (request) => request.isUser
      ? const [
          AgentStep.callTool('set_name', {'name': 'Marta Nowak'}),
          AgentStep.callTool('set_email', {'email': 'marta@acme.example'}),
          AgentStep.callTool('set_company', {'company': 'Acme Office Supply'}),
        ]
      : [
          AgentStep.say(
            request.problem ?? 'Contact filled. You can edit the fields.',
          ),
        ],
);

AgentConnection replyAgent() => _DemoAgent((request) {
  if (request.problem case final problem?) {
    return [AgentStep.say(problem)];
  }
  return switch (request.lastTool) {
    'send' => const [AgentStep.say('The reply was sent.')],
    _ when request.view == '' => const [
      AgentStep.callTool('set_reply', {
        'text':
            'Your parcel ships on Monday. '
            'We will email you the tracking link when it leaves our warehouse.',
      }),
    ],
    _ when request.lists('send') => const [AgentStep.callTool('send')],
    _ => const [AgentStep.say('The reply is already sent.')],
  };
});

AgentConnection _listAgent({
  required List<String> items,
  required String argument,
  required String action,
  required String done,
}) => _DemoAgent((request) {
  if (request.problem case final problem?) {
    return [AgentStep.say(problem)];
  }
  if (request.lastTool == action) {
    return [AgentStep.say(done)];
  }
  if (request.view case [] when request.isUser) {
    return [
      for (final item in items) AgentStep.callTool('add', {argument: item}),
    ];
  }
  return request.lists(action)
      ? [AgentStep.callTool(action)]
      : const [AgentStep.say('The list is empty.')];
});

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
