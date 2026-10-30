import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late TripsCubit trips;

  setUp(() => trips = TripsCubit(demoTrips(), inbox: const Inbox()));

  tearDown(() => trips.close());

  test('a new trip takes its place by its departure', () {
    trips.add(_vienna(DateTime(2026, 11, 4)));

    expect(
      [for (final trip in trips.state.trips) trip.id],
      ['paris', 'berlin', 'vienna', 'copenhagen'],
    );
  });

  test('the news of a trip leaves out receipts and what it follows', () {
    expect(
      [for (final email in trips.news('berlin')) email.subject],
      ['Workshop moves to Friday'],
    );
    expect(trips.news('paris'), isEmpty);
  });

  test('an invitation leaves the inbox once its trip is planned', () {
    expect([for (final email in trips.invitations) email.tripId], ['vienna']);

    trips.add(_vienna(DateTime(2026, 12, 8)));

    expect(trips.invitations, isEmpty);
  });

  test('what waits counts the invitations and the news of every trip', () {
    // The invitation to Vienna, the workshop in Berlin and the hotel in
    // Copenhagen.
    expect(trips.waiting, 3);
  });
}

Trip _vienna(DateTime day) {
  const flights = FlightSearch();
  final nextDay = day.add(const Duration(days: 1));
  return switch ((
    flights.find('WA 517', day),
    flights.find('WA 518', nextDay),
  )) {
    (final outbound?, final homebound?) => Trip(
      id: 'vienna',
      city: 'Vienna',
      booked: Itinerary(outbound: outbound, homebound: homebound, meetings: []),
    ),
    _ => fail('The flights to Vienna are not in the timetable.'),
  };
}
