import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

void main() {
  test(
    'arrival follows the current meeting and only offers available actions',
    () async {
      final events = await _run(
        messages: const [
          {'role': 'user', 'content': 'Show my arrival'},
        ],
        tools: const ['tandem_show_view'],
      );
      expect(
        _said(events),
        'The train gets you there by 12:42 for Review at 14:00.',
      );
      final arguments = [
        for (final event in events)
          if (event case {
            'type': 'TOOL_CALL_ARGS',
            'delta': final String delta,
          })
            delta,
      ].join();
      expect(arguments, isNot(contains('onBook')));
      expect(arguments, isNot(contains('onText')));
      expect(arguments, isNot(contains('onEarlyCheckIn')));

      final taxi = await _run(
        messages: const [
          {'role': 'user', 'content': 'Book a taxi'},
        ],
      );
      expect(
        _said(taxi),
        'Ride booking is not available right now. Check the current screen.',
      );
      expect(
        taxi.where((event) => event['type'] == 'TOOL_CALL_START'),
        isEmpty,
      );
    },
  );

  test(
    'a taxi outside the policy is refused before requesting a booking',
    () async {
      for (final overPolicy in [true, false]) {
        final events = await _run(
          messages: const [
            {'role': 'user', 'content': 'Book a taxi'},
          ],
          tools: const ['book_ride'],
          arrival: {
            ..._arrival,
            'rides': [
              {
                'id': 'taxi',
                'mode': 'taxi',
                'arrives': '2026-10-29T12:10:00',
                'overPolicy': overPolicy,
              },
            ],
          },
        );
        final calls = events.where(
          (event) => event['type'] == 'TOOL_CALL_START',
        );
        if (overPolicy) {
          expect(calls, isEmpty);
          expect(_said(events), contains('outside the company policy'));
        } else {
          expect(calls.single['toolCallName'], 'book_ride');
        }
      }
    },
  );

  test(
    'failed early check-in is reported without promising a ready room',
    () async {
      final events = await _run(
        messages: const [
          {'role': 'user', 'content': 'The app sent this'},
        ],
        note: const {
          'pressed': 'request_early_check_in',
          'status': 'failed',
          'error': 'Hotel unavailable.',
        },
      );
      expect(
        _said(events),
        'I could not confirm that action. Hotel unavailable.',
      );
    },
  );

  test(
    'successful actions use the actual host and reported room time',
    () async {
      for (final (tool, result, expected) in [
        ('message_host', 'On my way', 'Texted Mira: "On my way"'),
        (
          'request_early_check_in',
          null,
          'The hotel reports your room ready at 12:30.',
        ),
      ]) {
        final events = await _run(
          messages: [
            {
              'role': 'assistant',
              'toolCalls': [
                {
                  'id': 'action',
                  'function': {'name': tool},
                },
              ],
            },
            {
              'role': 'tool',
              'toolCallId': 'action',
              'content': jsonEncode(result),
            },
          ],
        );
        expect(_said(events), expected);
      }
    },
  );
}

Future<List<Map<String, Object?>>> _run({
  required List<Map<String, Object?>> messages,
  List<String> tools = const [],
  Map<String, Object?> arrival = _arrival,
  Map<String, Object?>? note,
}) => scriptedArrivalAgent().run({
  'threadId': 'arrival-test',
  'runId': 'arrival-reply',
  'tools': [
    for (final tool in tools) {'name': tool},
  ],
  'context': [
    {'description': 'arrival: The arrival day', 'value': jsonEncode(arrival)},
    if (note != null)
      {
        'description': 'app_notes: What happened in the app',
        'value': jsonEncode({
          'new': [note],
        }),
      },
  ],
  'messages': messages,
}).toList();

String _said(List<Map<String, Object?>> events) => [
  for (final event in events)
    if (event case {'type': 'TEXT_MESSAGE_CONTENT', 'delta': final String text})
      text,
].join();

const _arrival = {
  'meeting': {
    'title': 'Review',
    'start': '2026-10-29T14:00:00',
    'host': 'Mira',
  },
  'rides': [
    {'mode': 'taxi', 'arrives': '2026-10-29T12:10:00', 'overPolicy': true},
    {'mode': 'train', 'arrives': '2026-10-29T12:42:00', 'overPolicy': false},
  ],
  'hotel': {'roomReady': '2026-10-29T12:30:00'},
};
