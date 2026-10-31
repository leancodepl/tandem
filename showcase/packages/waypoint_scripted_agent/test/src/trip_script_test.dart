import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

void main() {
  test(
    'a refused or failed flight change never claims success or books',
    () async {
      for (final result in [
        {'status': 'refused', 'reason': 'The meeting ends after this flight.'},
        {
          'status': 'failed',
          'error': 'The provider did not confirm the change.',
        },
      ]) {
        final events = await scriptedTripAgent().run({
          'threadId': 'trip-test',
          'runId': 'trip-reply',
          'tools': [
            {'name': 'book_changes'},
          ],
          'context': [
            {
              'description': 'trip: the current trip',
              'value': jsonEncode({
                'unbookedChanges': [<String, Object?>{}],
                'unbookedCost': 122,
                'homebound': {'departs': 'Thu 2026-10-29 18:05'},
              }),
            },
          ],
          'messages': [
            {
              'role': 'assistant',
              'toolCalls': [
                {
                  'id': 'flight',
                  'function': {'name': 'set_homebound_flight'},
                },
              ],
            },
            {
              'role': 'tool',
              'toolCallId': 'flight',
              'content': jsonEncode(result),
            },
          ],
        }).toList();
        final said = [
          for (final event in events)
            if (event case {
              'type': 'TEXT_MESSAGE_CONTENT',
              'delta': final String text,
            })
              text,
        ].join();

        expect(said, contains(result['reason'] ?? result['error']));
        expect(said, isNot(contains('put you on')));
        expect(
          events.where((event) => event['type'] == 'TOOL_CALL_START'),
          isEmpty,
        );
      }
    },
  );
}
