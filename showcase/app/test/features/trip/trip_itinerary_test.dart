import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trip/trip_item_id.dart';
import 'package:waypoint/features/trip/trip_plan.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  List<DayPlan> planOfTrip(String tripId) {
    final booked = demoTrips()
        .singleWhere((trip) => trip.id == TripId(tripId))
        .booked;
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
        [
          TripItemId.outbound,
          TripItemId.meeting(MeetingId('kickoff')),
          TripItemId.hotel,
          TripItemId.meeting(MeetingId('dinner')),
        ],
        [TripItemId.meeting(MeetingId('workshop')), TripItemId.homebound],
      ],
    );
  });

  test('a meeting moved past the return stays on the timeline', () {
    final booked = demoTrips()
        .singleWhere((trip) => trip.id == TripId('berlin'))
        .booked;
    final current = booked.copyWith(
      meetings: [
        for (final meeting in booked.meetings)
          if (meeting.id == MeetingId('workshop'))
            meeting.movedTo(DateTime(2026, 10, 30, 10))
          else
            meeting,
      ],
    );

    final days = planOf(current, booked);

    expect(days.last.date, DateTime(2026, 10, 30));
    expect(days.last.items.map((item) => item.id), [
      TripItemId.meeting(MeetingId('workshop')),
    ]);
  });

  test('UTC meeting dates and local flight dates share calendar days', () {
    final booked = demoTrips()
        .singleWhere((trip) => trip.id == TripId('berlin'))
        .booked;
    final current = booked.copyWith(
      meetings: [
        for (final meeting in booked.meetings)
          if (meeting.id == MeetingId('workshop'))
            meeting.movedTo(DateTime.utc(2026, 10, 27, 10))
          else
            meeting,
      ],
    );

    final days = planOf(current, booked);

    expect(days.map((day) => day.date.day), [27, 28, 29]);
    expect(days.first.items.map((item) => item.id), [
      TripItemId.meeting(MeetingId('workshop')),
    ]);
    expect(days.last.items.map((item) => item.id), [TripItemId.homebound]);
  });

  test('an outlying meeting adds its day without years of empty days', () {
    final booked = demoTrips()
        .singleWhere((trip) => trip.id == TripId('berlin'))
        .booked;
    final current = booked.copyWith(
      meetings: [
        for (final meeting in booked.meetings)
          if (meeting.id == MeetingId('workshop'))
            meeting.movedTo(DateTime(2100, 1, 1, 10))
          else
            meeting,
      ],
    );

    final days = planOf(current, booked);

    expect(days, hasLength(3));
    expect(days.last.date, DateTime(2100));
    expect(days.last.items.map((item) => item.id), [
      TripItemId.meeting(MeetingId('workshop')),
    ]);
  });

  test('empty travel days use one section even with a distant return', () {
    final booked = demoTrips()
        .singleWhere((trip) => trip.id == TripId('berlin'))
        .booked;
    for (final (returnDate, rangeEnd) in [
      (DateTime(2026, 10, 31), null),
      (DateTime(2100), DateTime(2099, 12, 31)),
    ]) {
      final homebound = const FlightSearch().find(
        FlightNumber('WA 388'),
        returnDate,
      );
      if (homebound == null) fail('The flight home is in the timetable.');

      final days = planOf(booked.copyWith(homebound: homebound), booked);
      final gap = days.singleWhere((day) => day.items.isEmpty);

      expect(days, hasLength(4));
      expect(gap.date, DateTime(2026, 10, 30));
      expect(gap.endDate, rangeEnd);
      expect(days.last.date, returnDate);
      expect(days.last.items.map((item) => item.id), [TripItemId.homebound]);
    }
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
