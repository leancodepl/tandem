import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

void main() {
  test(
    'a refused booking field is explained instead of claiming success',
    () async {
      const reason = 'The check-in is outside this trip.';

      expect(
        await _reply({'status': 'refused', 'reason': reason}),
        'Some booking fields could not be filled in. $reason',
      );
      expect(await _reply(null), 'Filled in from the confirmation.');
    },
  );
}

Future<String> _reply(Object? result) async {
  final events = await scriptedBookingAgent().run({
    'threadId': 'booking-test',
    'runId': 'booking-reply',
    'messages': [
      {'role': 'tool', 'toolCallId': 'check-in', 'content': jsonEncode(result)},
    ],
  }).toList();
  return [
    for (final event in events)
      if (event case {
        'type': 'TEXT_MESSAGE_CONTENT',
        'delta': final String text,
      })
        text,
  ].join();
}
