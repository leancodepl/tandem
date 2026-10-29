import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trip/trip_action.dart';
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
      info: demoTrips().singleWhere((trip) => trip.id == 'berlin'),
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
    trip.moveMeeting('workshop', friday);

    activity.add(_action('move_meeting', {'meetingId': 'workshop'}), trip, 3);

    expect(activity.state.steps, [
      MeetingMovedStep(3, meeting: 'Design workshop', start: friday),
    ]);
  });

  test('a look-up of flights is a step with its route and day', () {
    activity.add(
      _action('find_flights', {
        'origin': 'BER',
        'destination': 'WAW',
        'date': '2026-10-30',
      }),
      trip,
      1,
    );

    expect(activity.state.steps, [
      FlightsLookedUpStep(
        1,
        origin: 'BER',
        destination: 'WAW',
        date: DateTime(2026, 10, 30),
      ),
    ]);
  });

  test('new hotel nights and a new flight home are steps with them', () {
    trip
      ..setHotelNights(2)
      ..setHomeboundFlight('WA 390', DateTime(2026, 10, 29));

    activity
      ..add(_action('set_hotel_nights'), trip, 1)
      ..add(_action('set_homebound_flight'), trip, 2);

    expect(activity.state.steps, [
      const HotelNightsStep(1, hotel: 'Spree Loft Hotel', nights: 2),
      FlightHomeStep(
        2,
        number: 'WA 390',
        departs: DateTime(2026, 10, 29, 20, 45),
      ),
    ]);
  });

  test('a call that shows nothing new is no step', () {
    activity
      ..add(_action('move_meeting', {'meetingId': 'lunch'}), trip, 1)
      ..add(_action('book_changes'), trip, 2);

    expect(activity.state.steps, isEmpty);
    expect(TripAction.of('tandem_show_view'), isNull);
  });
}

TripAction _action(String tool, [Map<String, Object?> arguments = const {}]) =>
    switch (TripAction.of(tool, arguments)) {
      final action? => action,
      null => fail('$tool is not a tool of the trip.'),
    };
