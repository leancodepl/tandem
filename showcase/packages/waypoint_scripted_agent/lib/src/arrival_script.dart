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
    return [AgentStep.say(_answer(request, tool, status, note))];
  }

  if (request.isUserMessage) {
    if (lastUserText(raw).toLowerCase().contains('taxi')) {
      return request.offersTool('book_ride')
          ? const [
              AgentStep.callTool('book_ride', {'rideId': 'taxi'}),
            ]
          : const [
              AgentStep.say(
                'Ride booking is not available right now. Check the current screen.',
              ),
            ];
    }
    return [
      if (request.offersTool('tandem_show_view'))
        AgentStep.callTool('tandem_show_view', {
          'components': _dayView(request),
        }),
      AgentStep.say(_arrivalSummary(request.context('arrival'))),
    ];
  }

  final result = request.latestToolResults.lastOrNull;
  if (result == null) {
    return const [AgentStep.say('Check the arrival day on the screen.')];
  }
  final value = result.value;
  final note = switch (value) {
    {'status': final String _} && final Map<String, Object?> details => details,
    _ => <String, Object?>{'result': value},
  };
  final status = switch (note['status']) {
    final String status => status,
    _ => 'returned',
  };
  return [AgentStep.say(_answer(request, result.toolName ?? '', status, note))];
}

String _answer(
  AgentRequest request,
  String tool,
  String status,
  Map<Object?, Object?> note,
) {
  if (status == 'rejected_by_user') return 'OK, I left it.';
  if (status == 'refused') {
    if (note['reason'] case final String reason) {
      return 'That did not go through: $reason';
    }
  }
  if (tool == 'tandem_show_view' && status == 'shown') {
    return 'The arrival day is on the screen.';
  }
  if (status != 'returned') {
    final detail =
        note['reason'] ?? note['error'] ?? 'Check the current screen.';
    return 'I could not confirm that action. $detail';
  }
  final arrival = request.context('arrival');
  final host = switch (arrival) {
    {'meeting': {'host': final String host}} => host,
    _ => null,
  };
  return switch ((tool, note['result'])) {
    ('book_ride', final String booking) =>
      'Booked: $booking.${host != null && request.offersTool('message_host') ? ' I can text $host that you are on your way.' : ''}',
    ('message_host', final String message) =>
      '${host == null ? 'Sent' : 'Texted $host'}: "$message"',
    ('request_early_check_in', _) => switch (arrival) {
      {'hotel': {'roomReady': final String ready}} => switch (DateTime.tryParse(
        ready,
      )) {
        final at? => 'The hotel reports your room ready at ${_time(at)}.',
        null => 'The early check-in was requested.',
      },
      _ => 'The early check-in was requested.',
    },
    _ => 'Done.',
  };
}

String _arrivalSummary(Object? arrival) {
  if (arrival case {
    'meeting': {'title': final String title, 'start': final String start},
    'rides': final List<Object?> rides,
  }) {
    final meeting = DateTime.tryParse(start);
    if (meeting != null) {
      for (final ride in rides) {
        if (ride case {
          'mode': final String mode,
          'arrives': final String arrival,
          'overPolicy': false,
        }) {
          final at = DateTime.tryParse(arrival);
          if (at != null && at.compareTo(meeting) <= 0) {
            return 'The $mode gets you there by ${_time(at)} for $title at ${_time(meeting)}.';
          }
        }
      }
      return '$title starts at ${_time(meeting)}. Check the available routes below.';
    }
  }
  return 'Check the meeting and route options on the arrival day.';
}

String _time(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

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
