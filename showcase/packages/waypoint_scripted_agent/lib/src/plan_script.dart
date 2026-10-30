import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint_scripted_agent/src/last_user_text.dart';

/// The new trip's agent: it plans the trip to Vienna from Alpenlicht's
/// invitation, choosing flights and a hotel the way a traveller would, within
/// what the app allows.
AgentConnection scriptedPlanAgent() => ScriptedAgent.repeating(_plan);

List<AgentStep> _plan(Map<String, Object?> raw) {
  final request = AgentRequest(raw);
  if (request.isUserMessage) {
    final text = lastUserText(raw);
    return text.contains('Vienna') || text.contains('Alpenlicht')
        ? _readTheInvitation
        : const [
            AgentStep.say(
              'This is a scripted assistant: it plans the trip to Vienna '
              "from Alpenlicht's invitation in the inbox.",
            ),
          ];
  }

  final results = request.latestToolResults;
  final flights = [
    for (final result in results)
      if (result.toolName == 'find_flights') result.value,
  ];
  final hotels = [
    for (final result in results)
      if (result.toolName == 'find_hotels') result.value,
  ];
  if ((flights, hotels) case (
    [final List<Object?> there, final List<Object?> home],
    [final List<Object?> stays],
  )) {
    return [
      ?_choose(there, 'set_outbound_flight', afternoon: true),
      ?_choose(home, 'set_homebound_flight'),
      ?_closestHotel(stays),
    ];
  }
  return [AgentStep.say(_summary(request))];
}

const _readTheInvitation = [
  AgentStep.callTool('set_city', {'city': 'Vienna'}),
  AgentStep.callTool('set_purpose', {'purpose': 'Discovery · Alpenlicht'}),
  AgentStep.callTool('add_meeting', {
    'title': 'Discovery workshop',
    'place': 'Alpenlicht, Mariahilfer Str. 88',
    'start': '2026-12-09T09:30:00',
    'end': '2026-12-09T17:00:00',
  }),
  AgentStep.callTool('add_meeting', {
    'title': 'Roadmap session',
    'place': 'Alpenlicht, Mariahilfer Str. 88',
    'start': '2026-12-10T09:00:00',
    'end': '2026-12-10T12:00:00',
  }),
  // The workshop starts at 09:30, so the policy wants the evening before.
  AgentStep.callTool('find_flights', {
    'origin': 'WAW',
    'destination': 'VIE',
    'date': '2026-12-08',
  }),
  AgentStep.callTool('find_flights', {
    'origin': 'VIE',
    'destination': 'WAW',
    'date': '2026-12-10',
  }),
  AgentStep.callTool('find_hotels', {'city': 'Vienna'}),
];

/// The first flight the policy allows, after noon when [afternoon], so that
/// the traveller does not leave at dawn the day before.
AgentStep? _choose(
  List<Object?> flights,
  String tool, {
  bool afternoon = false,
}) {
  for (final flight in flights) {
    if (flight case {
      'number': final String number,
      // As the app writes it: "Tue 2026-12-08 17:40".
      'departs': final String departs,
      'unavailable': null,
    }) {
      final [_, date, time] = departs.split(' ');
      if (afternoon && int.parse(time.split(':').first) < 12) {
        continue;
      }
      return AgentStep.callTool(tool, {'number': number, 'date': date});
    }
  }
  return null;
}

AgentStep? _closestHotel(List<Object?> hotels) {
  final allowed = [
    for (final hotel in hotels)
      if (hotel case {
        'id': final String id,
        'walkMinutes': final int minutes,
        'unavailable': null,
      })
        (id, minutes),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return switch (allowed.firstOrNull) {
    (final id, _)? => AgentStep.callTool('set_hotel', {'hotelId': id}),
    null => null,
  };
}

String _summary(AgentRequest request) => switch (request.context('plan')) {
  {
    'outbound': {'departs': final String there},
    'homebound': {'departs': final String home},
    'hotel': {'name': final String hotel, 'nights': final int nights},
    'total': final int total,
  } =>
    "Planned from Mira's invitation: the ${there.split(' ').last} on "
        'Tuesday, $nights nights at $hotel, the closest hotel within the policy, '
        'and the ${home.split(' ').last} home on Thursday. €$total in all; '
        'book it below.',
  _ => 'I could not plan all of it within the policy. Check what is missing.',
};
