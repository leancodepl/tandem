import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

void main() {
  test(
    'a refused or failed trip action never claims success or books',
    () async {
      for (final (tool, result) in [
        (
          'set_homebound_flight',
          {
            'status': 'refused',
            'reason': 'The meeting ends after this flight.',
          },
        ),
        (
          'set_homebound_flight',
          {
            'status': 'failed',
            'error': 'The provider did not confirm the change.',
          },
        ),
        ('book_changes', {'status': 'refused', 'reason': 'The trip changed.'}),
        (
          'book_changes',
          {
            'status': 'failed',
            'error': 'The provider did not confirm the booking.',
          },
        ),
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
                  'function': {'name': tool},
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

  test('booking describes current changes and needs the offered capability', () async {
    for (final offered in [true, false]) {
      final events = await scriptedTripAgent().run({
        'threadId': 'trip-test',
        'runId': 'trip-booking',
        'tools': [
          if (offered) {'name': 'book_changes'},
        ],
        'context': [
          {
            'description': 'trip: the current trip',
            'value': jsonEncode({
              'unbookedChanges': [
                <String, Object?>{},
                <String, Object?>{},
                <String, Object?>{},
              ],
              'unbookedCost': 215,
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
          {'role': 'tool', 'toolCallId': 'flight', 'content': 'null'},
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
      final calls = events.where((event) => event['type'] == 'TOOL_CALL_START');

      if (offered) {
        expect(said, 'The flight home is updated. Book 3 changes for €215?');
        expect(calls.single['toolCallName'], 'book_changes');
      } else {
        expect(
          said,
          'The flight home is updated. Check the current trip before booking.',
        );
        expect(calls, isEmpty);
      }
    }
  });
  test('a total-only hotel stays unchanged while flight-only approval names its warning', () async {
    const warning = 'No hotel for the night of Thu 29 Oct';
    final trip = {
      'hotel': {
        'name': 'Self-booked hotel',
        'nights': 1,
        'total': 245,
        'nightly': null,
      },
      'warnings': [warning],
      'unbookedChanges': [
        <String, Object?>{'what': 'Flight home WA 388'},
      ],
      'unbookedCost': 52,
    };
    Future<List<Map<String, Object?>>> run(
      List<Map<String, Object?>> messages,
    ) => scriptedTripAgent().run({
      'threadId': 'total-only-trip',
      'runId': 'workshop-move',
      'tools': [
        for (final name in [
          'move_meeting',
          'find_flights',
          'set_homebound_flight',
          'book_changes',
        ])
          {'name': name},
      ],
      'context': [
        {'description': 'trip: the current trip', 'value': jsonEncode(trip)},
      ],
      'messages': messages,
    }).toList();

    final moved = await run(const [
      {'role': 'user', 'content': 'The workshop moved to Friday'},
    ]);
    expect(_toolNames(moved), ['move_meeting', 'find_flights']);
    expect(_said(moved), contains('needs a nightly quote'));

    final asking = await run([
      {
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'flight',
            'function': {'name': 'set_homebound_flight'},
          },
        ],
      },
      {'role': 'tool', 'toolCallId': 'flight', 'content': 'null'},
    ]);
    expect(_toolNames(asking), ['book_changes']);
    expect(_said(asking), contains(warning));
    expect(_said(asking), contains('needs a nightly quote'));
    expect(_said(asking), contains('Book 1 change for €52?'));

    final booked = await run([
      {
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'booking',
            'function': {'name': 'book_changes'},
          },
        ],
      },
      {
        'role': 'tool',
        'toolCallId': 'booking',
        'content': jsonEncode({'confirmation': 'flight-only'}),
      },
    ]);
    expect(_said(booked), contains('Your confirmation is flight-only.'));
    expect(_said(booked), contains(warning));
    expect(_said(booked), isNot(contains('hotel is updated')));
  });
}

List<String> _toolNames(List<Map<String, Object?>> events) => [
  for (final event in events)
    if (event case {
      'type': 'TOOL_CALL_START',
      'toolCallName': final String name,
    })
      name,
];

String _said(List<Map<String, Object?>> events) => [
  for (final event in events)
    if (event case {'type': 'TEXT_MESSAGE_CONTENT', 'delta': final String text})
      text,
].join();
