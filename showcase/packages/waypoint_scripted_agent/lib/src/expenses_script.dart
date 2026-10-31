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
      if (receipt
          case {
            'id': final String id,
            'paid': final int paid,
            'category': final String category,
            'claimed': null,
          }
          when receipt['problem'] == null)
        (id: id, paid: paid, category: category),
  ];

  if (request.isUserMessage) {
    if (missing.isEmpty ||
        receipts.any(
          (receipt) => switch (receipt) {
            {'problem': final String _} => true,
            _ => false,
          },
        )) {
      return _askToSubmit(request);
    }
    if (request.offersTool('add_expense')) {
      return [
        for (final receipt in missing)
          AgentStep.callTool('add_expense', {
            'receiptId': receipt.id,
            'claimed': receipt.paid,
          }),
      ];
    }
    return const [
      AgentStep.say(
        'Expenses cannot be added right now. Check the current screen.',
      ),
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
        {'status': 'rejected_by_user'} =>
          "OK, the report stays unsubmitted. Submit it when you're ready.",
        {'reason': final String reason} =>
          'The report was not submitted: $reason',
        {'error': final String error} =>
          'I could not confirm whether the report was submitted. $error',
        _ => 'I could not confirm whether the report was submitted. Check the current screen.',
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
      final meals = missing
          .where((receipt) => receipt.category == 'meal')
          .toList();
      if ((left, meals) case (final left?, [final meal])
          when left != '0' && request.offersTool('add_expense')) {
        return [
          AgentStep.callTool('add_expense', {
            'receiptId': meal.id,
            'claimed': int.parse(left),
          }),
        ];
      }
      return [AgentStep.say('The expense was not added: $reason')];
    }
    if (result.value case {'status': final String status} && final details
        when status != 'returned') {
      final reason =
          details['error'] ?? details['reason'] ?? 'Check the current screen.';
      return [AgentStep.say('I could not confirm the expense change. $reason')];
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
  if (report case {'receipts': final List<Object?> receipts}
      when receipts.any(
        (receipt) => switch (receipt) {
          {'claimed': null} => true,
          _ => false,
        },
      )) {
    return const [
      AgentStep.say(
        'Some receipts are not in the report. Review them before submitting.',
      ),
    ];
  }
  if (!request.offersTool('submit_report')) {
    return const [
      AgentStep.say(
        'The report cannot be submitted right now. Check the current screen.',
      ),
    ];
  }
  if (report case {'total': final int total}) {
    return [
      AgentStep.say('The report claims €$total. Submit the report?'),
      const AgentStep.callTool('submit_report'),
    ];
  }
  return const [AgentStep.say('Check the current report before submitting.')];
}
