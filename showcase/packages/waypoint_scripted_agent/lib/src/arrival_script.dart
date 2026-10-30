import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint_scripted_agent/src/last_user_text.dart';

/// The arrival day's agent: it draws the day with Waypoint's widgets, and
/// answers what the traveller does with the view's buttons.
AgentConnection scriptedArrivalAgent() => ScriptedAgent.repeating(_arrival);

List<AgentStep> _arrival(Map<String, Object?> raw) {
  final request = AgentRequest(raw);

  // A button of the view: its answer comes as an app note.
  if (request.newNotes.lastOrNull
      case {'pressed': final String tool, 'status': final String status} &&
          final note) {
    return [AgentStep.say(_answer(tool, status, note))];
  }

  if (request.isUserMessage) {
    if (lastUserText(raw).toLowerCase().contains('taxi')) {
      return const [
        AgentStep.callTool('book_ride', {'rideId': 'taxi'}),
      ];
    }
    return [
      AgentStep.callTool('tandem_show_view', {'components': _dayView(request)}),
      const AgentStep.say(
        'You land at 08:40. The S-Bahn gets you to Studio Kraft by 09:42, '
        'in good time for the kickoff at 11:00.',
      ),
    ];
  }

  return switch (request.latestToolResults.lastOrNull?.value) {
    {'status': 'refused', 'reason': final String reason} => [
      AgentStep.say(
        "I can't book the taxi: $reason. The S-Bahn is booked "
        'from the view in one tap.',
      ),
    ],
    _ => const [AgentStep.say('Done.')],
  };
}

String _answer(String tool, String status, Map<Object?, Object?> note) =>
    switch ((tool, status, note['result'], note['reason'])) {
      (_, 'refused', _, final String reason) =>
        'That did not go through: '
            '$reason.',
      (_, 'rejected_by_user', _, _) => 'OK, I left it.',
      ('book_ride', _, final String booking, _) =>
        'Booked: $booking. I can text Lena that you are on your way.',
      ('message_host', _, final String message, _) => 'Texted Lena: "$message"',
      ('request_early_check_in', _, _, _) =>
        'The hotel will have your room ready at 13:00, so you can drop your '
            'bags after the kickoff.',
      _ => 'Done.',
    };

/// The arrival day in Waypoint's components, with a button only for a
/// method the screen offers now.
List<Map<String, Object?>> _dayView(AgentRequest request) {
  Map<String, Object?> action(String tool, [Map<String, Object?>? context]) => {
    'action': {
      'event': {'name': tool, 'context': ?context},
    },
  };

  return [
    {
      'id': 'root',
      'component': 'ArrivalCard',
      'title': 'After you land',
      'children': ['next', 'rides', 'host', 'hotel'],
    },
    {
      'id': 'next',
      'component': 'NextStop',
      'title': {'path': '/arrival/meeting/title'},
      'place': {'path': '/arrival/meeting/place'},
      'start': {'path': '/arrival/meeting/start'},
    },
    {
      'id': 'rides',
      'component': 'ArrivalColumn',
      'children': {'componentId': 'ride', 'path': '/arrival/rides'},
    },
    {
      'id': 'ride',
      'component': 'RideOption',
      'mode': {'path': 'mode'},
      'minutes': {'path': 'minutes'},
      'fare': {'path': 'fare'},
      'arrives': {'path': 'arrives'},
      'booked': {'path': 'booked'},
      'overPolicy': {'path': 'overPolicy'},
      if (request.offersTool('book_ride'))
        'onBook': action('book_ride', {
          'rideId': {'path': 'id'},
        }),
    },
    {
      'id': 'host',
      'component': 'HostNote',
      'name': {'path': '/arrival/meeting/host'},
      'told': {'path': '/arrival/meeting/hostTold'},
      if (request.offersTool('message_host')) 'onText': action('message_host'),
    },
    {
      'id': 'hotel',
      'component': 'HotelNote',
      'name': {'path': '/arrival/hotel/name'},
      'checkIn': {'path': '/arrival/hotel/checkIn'},
      'roomReady': {'path': '/arrival/hotel/roomReady'},
      if (request.offersTool('request_early_check_in'))
        'onEarlyCheckIn': action('request_early_check_in'),
    },
  ];
}
