import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  const flights = FlightSearch();

  Flight flight(String number, DateTime date) =>
      switch (flights.find(FlightNumber(number), date)) {
        final flight? => flight,
        null => fail('$number is not in the timetable.'),
      };

  Meeting meeting(String title, DateTime start, DateTime end) => Meeting(
    id: MeetingId(title),
    title: title,
    place: 'Vienna',
    start: start,
    end: end,
  );

  test('the booked demo trips satisfy the flight policy', () {
    for (final trip in demoTrips()) {
      final booked = trip.booked;
      expect(
        Policy.checkOutbound(booked.outbound, booked.meetings),
        isNull,
        reason: trip.id.value,
      );
      expect(
        Policy.checkHomebound(booked.homebound, booked.meetings),
        isNull,
        reason: trip.id.value,
      );
    }
  });

  test('a meeting before noon needs a flight the day before', () {
    final workshop = meeting(
      'Workshop',
      DateTime(2026, 12, 9, 9, 30),
      DateTime(2026, 12, 9, 17),
    );
    final sameDay = flight('WA 511', DateTime(2026, 12, 9));

    expect(
      Policy.checkOutbound(sameDay, [workshop]),
      LandsOnMeetingDay(sameDay, workshop),
    );
    expect(
      Policy.checkOutbound(flight('WA 517', DateTime(2026, 12, 8)), [workshop]),
      isNull,
    );
  });

  test('a flight there lands at least an hour before the first meeting', () {
    final lunch = meeting(
      'Lunch',
      DateTime(2026, 12, 9, 13),
      DateTime(2026, 12, 9, 14),
    );
    final evening = flight('WA 517', DateTime(2026, 12, 9));

    expect(
      Policy.checkOutbound(evening, [lunch]),
      LandsTooLate(evening, lunch),
    );
    expect(
      Policy.checkOutbound(flight('WA 511', DateTime(2026, 12, 9)), [lunch]),
      isNull,
    );
  });

  test('a late flight reports lateness before the overnight requirement', () {
    final morning = meeting(
      'Workshop',
      DateTime(2026, 12, 9, 9, 30),
      DateTime(2026, 12, 9, 17),
    );
    for (final date in [DateTime(2026, 12, 9), DateTime(2026, 12, 10)]) {
      final late = flight('WA 517', date);

      expect(
        Policy.checkOutbound(late, [morning]),
        LandsTooLate(late, morning),
      );
    }
  });

  test('offset meeting times use the same clock as the flight timetable', () {
    final workshop = meeting(
      'Workshop',
      travelDateTime(DateTime.parse('2026-12-09T12:30:00+01:00')),
      travelDateTime(DateTime.parse('2026-12-09T17:00:00Z')),
    );
    final earlyHome = flight('WA 518', DateTime(2026, 12, 9));

    expect(
      Policy.checkOutbound(flight('WA 511', DateTime(2026, 12, 9)), [workshop]),
      isNull,
    );
    expect(
      Policy.checkHomebound(earlyHome, [workshop]),
      LeavesTooEarly(earlyHome, workshop),
    );
    expect(
      Policy.checkHomebound(flight('WA 520', DateTime(2026, 12, 9)), [
        workshop,
      ]),
      isNull,
    );
  });

  test('a flight home leaves an hour after the meeting that ends last', () {
    final steering = meeting(
      'Steering group',
      DateTime(2026, 12, 9, 10),
      DateTime(2026, 12, 9, 20),
    );
    final coffee = meeting(
      'Coffee',
      DateTime(2026, 12, 9, 17),
      DateTime(2026, 12, 9, 17, 30),
    );
    final early = flight('WA 518', DateTime(2026, 12, 9));

    expect(
      Policy.checkHomebound(early, [steering, coffee]),
      LeavesTooEarly(early, steering),
    );
    expect(
      Policy.checkHomebound(flight('WA 520', DateTime(2026, 12, 9)), [
        steering,
        coffee,
      ]),
      isNull,
    );
  });

  test('a hotel night costs at most the limit', () {
    expect(Policy.checkNightly(Policy.maxNightly), isNull);
    expect(
      Policy.checkNightly(Policy.maxNightly + wholeMoney(1)),
      OverNightly(Policy.maxNightly + wholeMoney(1)),
    );
  });

  test('meals of a day pay back up to the daily limit', () {
    expect(
      Policy.checkMeals(
        claimed: wholeMoney(18),
        claimedThatDay: wholeMoney(42),
      ),
      isNull,
    );
    expect(
      Policy.checkMeals(
        claimed: wholeMoney(30),
        claimedThatDay: wholeMoney(42),
      ),
      OverMealsPerDay(wholeMoney(18)),
    );
  });

  test('a taxi only when the train is late for the meeting', () {
    final meeting = DateTime(2026, 10, 28, 11);
    final early = DateTime(2026, 10, 28, 9, 42);

    expect(
      Policy.checkRide(.taxi, trainArrives: early, meetingStarts: meeting),
      TaxiNotNeeded(trainArrives: early, meetingStarts: meeting),
    );
    expect(
      Policy.checkRide(
        .taxi,
        trainArrives: DateTime(2026, 10, 28, 11, 5),
        meetingStarts: meeting,
      ),
      isNull,
    );
    expect(
      Policy.checkRide(.train, trainArrives: early, meetingStarts: meeting),
      isNull,
    );
  });
}
