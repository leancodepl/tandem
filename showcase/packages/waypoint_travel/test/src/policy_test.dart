import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  const flights = FlightSearch();

  Flight flight(String number, DateTime date) =>
      switch (flights.find(number, date)) {
        final flight? => flight,
        null => fail('$number is not in the timetable.'),
      };

  Meeting meeting(String title, DateTime start, DateTime end) =>
      Meeting(id: title, title: title, place: 'Vienna', start: start, end: end);

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
      Policy.checkNightly(Policy.maxNightly + 1),
      const OverNightly(Policy.maxNightly + 1),
    );
  });

  test('meals of a day pay back up to the daily limit', () {
    expect(Policy.checkMeals(claimed: 18, claimedThatDay: 42), isNull);
    expect(
      Policy.checkMeals(claimed: 30, claimedThatDay: 42),
      const OverMealsPerDay(18),
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
