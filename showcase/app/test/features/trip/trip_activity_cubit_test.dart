import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_activity.dart';
import 'package:waypoint/features/trip/trip_activity_cubit.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late TripCubit trip;
  late ActivityCubit activity;

  setUp(() {
    trip = TripCubit(
      info: demoTrips().singleWhere((trip) => trip.id == TripId('berlin')),
      trips: TripsCubit(demoTrips(), inbox: const Inbox()),
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
    activity = ActivityCubit();
  });

  tearDown(() async {
    await trip.close();
    await activity.close();
  });

  test('a moved meeting is a step with its new start', () {
    final friday = DateTime(2026, 10, 30, 10);
    trip.moveMeeting(' workshop ', friday);

    activity.add(_action(.moveMeeting, {'meetingId': ' workshop '}), trip, 3);

    expect(activity.state.steps, [
      MeetingMovedStep(3, meeting: 'Design workshop', start: friday),
    ]);
  });

  test('a look-up of flights is a step with its route and day', () {
    activity.add(
      _action(.findFlights, {
        'origin': ' ber ',
        'destination': ' waw ',
        'date': '2026-10-30',
      }),
      trip,
      1,
    );

    expect(activity.state.steps, [
      FlightsLookedUpStep(
        1,
        origin: AirportCode('BER'),
        destination: AirportCode('WAW'),
        date: DateTime(2026, 10, 30),
      ),
    ]);
  });

  test('new hotel nights and a new flight home are steps with them', () {
    trip
      ..setHotelNights(2)
      ..setHomeboundFlight('WA 390', DateTime(2026, 10, 29));

    activity
      ..add(_action(.setHotelNights), trip, 1)
      ..add(_action(.setHomeboundFlight), trip, 2);

    expect(activity.state.steps, [
      HotelNightsStep(1, hotel: 'Spree Loft Hotel', nights: NightCount(2)),
      FlightHomeStep(
        2,
        number: FlightNumber('WA 390'),
        departs: DateTime(2026, 10, 29, 20, 45),
      ),
    ]);
  });

  test('a call that shows nothing new is no step', () {
    activity
      ..add(_action(.moveMeeting, {'meetingId': 'lunch'}), trip, 1)
      ..add(_action(.bookChanges), trip, 2);

    expect(activity.state.steps, isEmpty);
  });
}

TripAction _action(
  TripCubitTool tool, [
  Map<String, Object?> arguments = const {},
]) => switch (TripAction.of(tool, arguments)) {
  final action? => action,
  null => fail('$tool is not a tool of the trip.'),
};
