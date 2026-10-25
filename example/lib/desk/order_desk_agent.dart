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

  /// The decoded value of the screen's only `.sees`.
  Object? get view => switch (this) {
    {'context': [{'value': final String value}]} => jsonDecode(value),
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
          switch (status) {
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
