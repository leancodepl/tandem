import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

/// The expense report's agent: it adds the trip's receipts within the
/// policy, takes what the app says is left when a meal goes over the daily
/// limit, and asks to submit the report.
AgentConnection scriptedExpensesAgent() => ScriptedAgent.repeating(_expenses);

List<AgentStep> _expenses(Map<String, Object?> raw) {
  final request = AgentRequest(raw);
  final receipts = switch (request.context('report')) {
    {'receipts': final List<Object?> receipts} => receipts,
    _ => const <Object?>[],
  };
  final missing = [
    for (final receipt in receipts)
      if (receipt case {
        'id': final String id,
        'paid': final int paid,
        'category': final String category,
        'claimed': null,
      })
        (id, paid, category),
  ];

  if (request.isUserMessage) {
    return [
      for (final (id, paid, _) in missing)
        AgentStep.callTool('add_expense', {'receiptId': id, 'claimed': paid}),
      if (missing.isEmpty) ..._askToSubmit(request),
    ];
  }

  final results = request.latestToolResults;
  if (results.lastOrNull case final last?
      when last.toolName == 'submit_report') {
    return [
      AgentStep.say(switch (last.value) {
        {'confirmation': final String confirmation, 'total': final int total} =>
          'Submitted as $confirmation. €$total comes back with your next '
              'salary.',
        _ => "OK, the report stays unsubmitted. Submit it when you're ready.",
      }),
    ];
  }

  // A meal over the daily limit: the app says what is left for that day.
  for (final result in results) {
    if (result.value case {
      'status': 'refused',
      'reason': final String reason,
    }) {
      final left = RegExp(r'€(\d+) is left').firstMatch(reason)?[1];
      final meal = missing.where((receipt) => receipt.$3 == 'meal');
      if ((left, meal.firstOrNull) case (final left?, (final id, _, _)?)
          when left != '0') {
        return [
          AgentStep.callTool('add_expense', {
            'receiptId': id,
            'claimed': int.parse(left),
          }),
        ];
      }
    }
  }
  return _askToSubmit(request);
}

List<AgentStep> _askToSubmit(AgentRequest request) {
  final report = request.context('report');
  if (report case {'submitted': final String _}) {
    return const [AgentStep.say('The report is submitted already.')];
  }
  final problems = [
    if (report case {'receipts': final List<Object?> receipts})
      for (final receipt in receipts)
        if (receipt case {
          'merchant': final String merchant,
          'problem': final String problem,
        })
          '$merchant: $problem',
  ];
  if (problems.isNotEmpty) {
    return [
      AgentStep.say(
        'Some claims are wrong. ${problems.join('. ')}. Change them on the '
        'screen, then submit the report.',
      ),
    ];
  }
  if (!request.offersTool('submit_report')) {
    return const [AgentStep.say('The report has no expense to submit yet.')];
  }
  return _submit(request);
}

List<AgentStep> _submit(AgentRequest request) {
  final total = switch (request.context('report')) {
    {'total': final int total} => total,
    _ => 0,
  };
  return [
    AgentStep.say(
      'All receipts are in: €$total paid back. The dinner went over the '
      "policy's €60 a day for meals, so only what was left for that day is "
      'paid back. Submit the report?',
    ),
    const AgentStep.callTool('submit_report'),
  ];
}
