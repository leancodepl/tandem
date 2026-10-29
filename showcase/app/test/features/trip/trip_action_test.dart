import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('every tool of the trip reads as its action, with its arguments', () {
    final trip = TripCubit(
      info: demoTrips().singleWhere((trip) => trip.id == 'berlin'),
      trips: TripsCubit(demoTrips(), inbox: const Inbox()),
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
    addTearDown(trip.close);

    final actions = [
      for (final tool in trip.agentSchema.calls)
        switch (TripAction.of(tool.name, _arguments(tool))) {
          final action? => action,
          null => fail('${tool.name} reads as no action.'),
        },
    ];

    expect(actions.map((action) => action.runtimeType).toSet(), {
      FindFlights,
      MoveMeeting,
      SetHomeboundFlight,
      SetHotelNights,
      BookChanges,
    });
    for (final action in actions) {
      final arguments = switch (action) {
        FindFlights(:final origin, :final destination, :final date) => [
          origin,
          destination,
          date,
        ],
        MoveMeeting(:final meetingId) => [meetingId],
        SetHomeboundFlight() ||
        SetHotelNights() ||
        BookChanges() => const <Object?>[],
      };
      expect(arguments, everyElement(isNotNull), reason: '$action');
    }
  });
}

/// One value of its type for each parameter of [tool], as the agent sends
/// it.
Map<String, Object?> _arguments(AgentTool tool) => {
  for (final parameter in tool.parameters)
    parameter.name: switch (parameter.type) {
      AgentType.dateTime => '2026-10-29T18:05:00',
      AgentType.integer => 2,
      _ => 'WAW',
    },
};
