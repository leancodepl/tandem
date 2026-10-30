import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trip/trip_itinerary.dart';
import 'package:waypoint_travel/demo.dart';

void main() {
  List<DayPlan> planOfTrip(String tripId) {
    final booked = demoTrips().singleWhere((trip) => trip.id == tripId).booked;
    return planOf(booked, booked);
  }

  test('each day of the trip lists its items in the order of time', () {
    final days = planOfTrip('berlin');

    expect(
      [for (final day in days) day.date],
      [DateTime(2026, 10, 28), DateTime(2026, 10, 29)],
    );
    expect(
      [
        for (final day in days) [for (final item in day.items) item.id],
      ],
      [
        ['outbound', 'kickoff', 'hotel', 'dinner'],
        ['workshop', 'homebound'],
      ],
    );
  });

  test('a trip over a night without a hotel has a place for one', () {
    final first = planOfTrip('copenhagen').first;

    expect(first.items, [
      isA<FlightItem>(),
      isA<MeetingItem>(),
      isA<NoHotelItem>(),
    ]);
  });
}
