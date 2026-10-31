import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

void main() {
  test(
    'failed expense changes do not trigger submission or claim success',
    () async {
      final events = await _reply(
        result: const {
          'status': 'failed',
          'error': 'The change may have happened.',
        },
      );

      expect(
        _said(events),
        'I could not confirm the expense change. The change may have happened.',
      );
      expect(_calls(events), isEmpty);
    },
  );

  test(
    'submission describes actual claims and waits for missing receipts',
    () async {
      final missing = await _reply(claimed: null);
      expect(
        _said(missing),
        'Some receipts are not in the report. Review them before submitting.',
      );
      expect(_calls(missing), isEmpty);

      final complete = await _reply();
      expect(_said(complete), 'The report claims €12. Submit the report?');
      expect(_calls(complete).single['toolCallName'], 'submit_report');

      final locked = await _reply(tools: const []);
      expect(
        _said(locked),
        'The report cannot be submitted right now. Check the current screen.',
      );
      expect(_calls(locked), isEmpty);
    },
  );

  test(
    'an uncertain submission does not claim that nothing was submitted',
    () async {
      final events = await _reply(
        tool: 'submit_report',
        result: const {
          'status': 'failed',
          'error': 'No acknowledgement was received.',
        },
      );

      expect(
        _said(events),
        'I could not confirm whether the report was submitted. No acknowledgement was received.',
      );
      expect(_calls(events), isEmpty);
    },
  );
  test(
    'a refused meal is not guessed from multiple missing receipts',
    () async {
      final events = await _reply(
        tools: const ['add_expense', 'submit_report'],
        receipts: const [
          {'id': 'first', 'category': 'meal', 'paid': 71, 'claimed': null},
          {'id': 'second', 'category': 'meal', 'paid': 71, 'claimed': null},
        ],
        result: const {
          'status': 'refused',
          'reason': 'Meals are paid back up to €60 a day, and €42 is left for that day.',
        },
      );

      expect(_said(events), contains('The expense was not added:'));
      expect(_calls(events), isEmpty);
    },
  );
  test(
    'a manual invalid claim is explained without trying to add its receipt',
    () async {
      final events = await _reply(
        initial: true,
        tools: const ['add_expense', 'submit_report'],
        receipts: const [
          {
            'id': 'taxi',
            'merchant': 'Taxi',
            'category': 'taxi',
            'paid': 58,
            'claimed': null,
            'problem': 'Claim between €1 and the €58 paid',
          },
        ],
      );

      expect(
        _said(events),
        contains('Taxi: Claim between €1 and the €58 paid'),
      );
      expect(_calls(events), isEmpty);
    },
  );
}

Future<List<Map<String, Object?>>> _reply({
  String tool = 'add_expense',
  Object? result,
  int? claimed = 12,
  List<String> tools = const ['submit_report'],
  List<Map<String, Object?>>? receipts,
  bool initial = false,
}) => scriptedExpensesAgent().run({
  'threadId': 'expenses-test',
  'runId': 'expenses-reply',
  'tools': [
    for (final tool in tools) {'name': tool},
  ],
  'context': [
    {
      'description': 'report: The current report',
      'value': jsonEncode({
        'receipts':
            receipts ??
            [
              {
                'id': 'receipt',
                'merchant': 'Train',
                'category': 'transport',
                'paid': 12,
                'claimed': claimed,
              },
            ],
        'total': claimed ?? 0,
      }),
    },
  ],
  'messages': initial
      ? [
          {'role': 'user', 'content': 'Check the report'},
        ]
      : [
          {
            'role': 'assistant',
            'toolCalls': [
              {
                'id': 'expense',
                'function': {'name': tool},
              },
            ],
          },
          {
            'role': 'tool',
            'toolCallId': 'expense',
            'content': jsonEncode(result),
          },
        ],
}).toList();

String _said(List<Map<String, Object?>> events) => [
  for (final event in events)
    if (event case {'type': 'TEXT_MESSAGE_CONTENT', 'delta': final String text})
      text,
].join();

Iterable<Map<String, Object?>> _calls(List<Map<String, Object?>> events) =>
    events.where((event) => event['type'] == 'TOOL_CALL_START');
