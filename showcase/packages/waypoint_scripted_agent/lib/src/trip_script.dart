import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint_scripted_agent/src/flight_choice.dart';
import 'package:waypoint_scripted_agent/src/last_user_text.dart';

/// The trip's agent: when the workshop in Berlin moves to Friday, it fits
/// the hotel and the flight home around it and asks to book the changes.
AgentConnection scriptedTripAgent() => ScriptedAgent.repeating(_trip);

List<AgentStep> _trip(Map<String, Object?> raw) {
  final request = AgentRequest(raw);
  if (request.isUserMessage) {
    // The app's notes come with a wake-up, the traveller's words without.
    final said = [
      lastUserText(raw),
      for (final note in request.newNotes)
        if (note case {'note': final String text}) text,
    ].join('\n');
    if (said.contains('changed the trip on the screen')) {
      return _askToBook(request, 'The trip changed.');
    }
    if (said.toLowerCase().contains('workshop')) {
      return _moveTheWorkshop;
    }
    return const [
      AgentStep.say(
        'This is a scripted assistant: it knows that the workshop in Berlin '
        'moves to Friday.',
      ),
    ];
  }

  final answers = {
    for (final result in request.latestToolResults)
      result.toolName: result.value,
  };
  return switch (answers) {
    {'book_changes': {'confirmation': final String confirmation}} => [
      AgentStep.say('Booked. Your confirmation is $confirmation.'),
    ],
    {'book_changes': {'status': 'rejected_by_user'}} => const [
      AgentStep.say("OK, I won't book them."),
    ],
    {'book_changes': {'status': _}} => const [
      AgentStep.say('The trip changed, so nothing was booked.'),
    ],
    {'find_flights': final List<Object?> flights} => [
      _firstFlightAllowed(flights),
    ],
    {'set_homebound_flight': {'status': final String status} && final result}
        when status != 'returned' =>
      [
        AgentStep.say(switch (result) {
          {'status': 'refused', 'reason': final String reason} =>
            'The flight was not changed: $reason',
          {'reason': final String reason} =>
            'I could not confirm the flight change: $reason',
          {'error': final String error} =>
            'I could not confirm the flight change: $error',
          _ => 'The flight change was not confirmed. Check the trip before booking.',
        }),
      ],
    {'set_homebound_flight': _} => _askToBook(
      request,
      'The workshop is on Friday now, so I added a night at the hotel and '
      'put you on the ${_homeboundTime(request)} flight home.',
    ),
    _ => const [AgentStep.say('Done.')],
  };
}

const _moveTheWorkshop = [
  AgentStep.callTool('move_meeting', {
    'meetingId': 'workshop',
    'start': '2026-10-30T10:00:00',
  }),
  AgentStep.callTool('set_hotel_nights', {'nights': 2}),
  AgentStep.callTool('find_flights', {
    'origin': 'BER',
    'destination': 'WAW',
    'date': '2026-10-30',
  }),
];

/// [lead], then book_changes with what it books, as the screen shows it.
List<AgentStep> _askToBook(AgentRequest request, String lead) {
  final changes = switch (request.context('trip')) {
    {
      'unbookedChanges': final List<Object?> changes,
      'unbookedCost': final int cost,
    }
        when request.offersTool('book_changes') =>
      '${changes.length} changes for €$cost',
    _ => null,
  };
  return switch (changes) {
    final changes? => [
      AgentStep.say('$lead Book $changes?'),
      const AgentStep.callTool('book_changes'),
    ],
    null => [AgentStep.say('$lead Nothing is left to book.')],
  };
}

AgentStep _firstFlightAllowed(List<Object?> flights) {
  if (FlightChoice.allowed(flights).firstOrNull case final flight?) {
    return AgentStep.callTool('set_homebound_flight', {
      'number': flight.number,
      'date': flight.dateArgument,
    });
  }
  return const AgentStep.say('No flight home fits after the workshop.');
}

String _homeboundTime(AgentRequest request) => switch (request.context(
  'trip',
)) {
  {'homebound': {'departs': final String departs}} => departs.split(' ').last,
  _ => 'evening flight',
};
