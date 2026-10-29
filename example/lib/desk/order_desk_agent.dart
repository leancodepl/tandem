import 'package:example/desk/desk_catalog.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

AgentConnection orderDeskAgent() => ScriptedAgent.repeating((raw) {
  final request = AgentRequest(raw);
  if (request.newNotes.lastOrNull case {
    'pressed': 'place_order',
    'result': final id,
  }) {
    return [AgentStep.say('You placed order $id from the summary.')];
  }
  if (request.isUserMessage) {
    if (request.offersTool('set_quantity')) {
      if (request.context('order') case {'lines': []}) {
        return [
          const AgentStep.callTool('set_customer', {'customerId': 'acme'}),
          const AgentStep.callTool('set_quantity', {
            'sku': 'VC-HDMI-2M',
            'quantity': 40,
          }),
          const AgentStep.callTool('set_quantity', {
            'sku': 'VM-27Q',
            'quantity': 12,
          }),
          const AgentStep.callTool('set_delivery', {
            'address': 'Magazynowa 5, 61-001 Poznań',
            'date': '2026-10-23',
          }),
          AgentStep.callTool('tandem_show_view', {
            'components': const DeskCatalog().example,
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

String? _problem(List<AgentToolResult> results) {
  // This script's app calls return null or an id; objects are control answers.
  for (final result in results.reversed) {
    if (result.value case {'status': final String status}
        when status != 'shown') {
      return switch (status) {
        'rejected_by_user' => 'You rejected the action. It did not run.',
        'invalidated' =>
          'What I saw changed. Ask again to use the current values.',
        'cancelled' =>
          'The action was cancelled. Ask again when you are ready.',
        _ =>
          'The action did not go through. '
              'Check the screen before trying again.',
      };
    }
  }
  return null;
}
