import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  final berlin = demoTrips().singleWhere((trip) => trip.id == TripId('berlin'));

  test('a trip is past once its flight home has left', () {
    expect(berlin.isPastOn(DateTime(2026, 10, 29)), isFalse);
    expect(berlin.isPastOn(DateTime(2026, 10, 30)), isTrue);
  });

  test('a moved meeting keeps its length', () {
    final workshop = berlin.booked.meeting(MeetingId('workshop'));

    final moved = workshop?.movedTo(DateTime(2026, 10, 30, 9));

    expect(moved?.end, DateTime(2026, 10, 30, 15));
  });

  test('an itinerary owns an immutable snapshot of its meetings', () {
    final meetings = [...berlin.booked.meetings];
    final itinerary = berlin.booked.copyWith(meetings: meetings);

    meetings.clear();

    expect(itinerary.meetings, berlin.booked.meetings);
    expect(itinerary.meetings.clear, throwsUnsupportedError);
  });

  test('a hotel checkout keeps its clock time across calendar nights', () {
    final hotel = berlin.booked.hotel;
    if (hotel == null) fail('The Berlin trip has a hotel.');

    for (final checkIn in [
      DateTime(2026, 3, 28, 15),
      DateTime(2026, 10, 24, 15),
    ]) {
      final stay = hotel.copyWith(checkIn: checkIn, nights: NightCount(2));

      expect(
        stay.checkOut,
        DateTime(checkIn.year, checkIn.month, checkIn.day + 2, 15),
      );
    }
  });

  test('a departure keeps its identity in UTC and when repriced', () {
    final flight = berlin.booked.homebound;
    final repriced = Flight(
      number: flight.number,
      origin: flight.origin,
      destination: flight.destination,
      departs: flight.departs.toUtc(),
      arrives: flight.arrives.toUtc(),
      fare: flight.fare + wholeMoney(10),
    );

    expect(flight.isSameDepartureAs(repriced), isTrue);
    expect(flight, isNot(repriced));
    expect(flight.isSameDepartureAs(berlin.booked.outbound), isFalse);
  });

  test('a flight needs a nonnegative fare and arrival after departure', () {
    final departure = DateTime(2026, 10, 29, 18);
    for (final (arrival, fare) in [
      (departure, wholeMoney(152)),
      (departure.subtract(const Duration(minutes: 1)), wholeMoney(152)),
      (departure.add(const Duration(hours: 1)), wholeMoney(-1)),
    ]) {
      expect(
        () => Flight(
          number: FlightNumber('WA 388'),
          origin: AirportCode('BER'),
          destination: AirportCode('WAW'),
          departs: departure,
          arrives: arrival,
          fare: fare,
        ),
        throwsArgumentError,
      );
    }
  });

  test('a meeting must end after it starts', () {
    final start = DateTime(2026, 10, 29, 10);
    expect(
      () => Meeting(
        id: MeetingId('workshop'),
        title: 'Workshop',
        place: 'Studio Kraft',
        start: start,
        end: start,
      ),
      throwsArgumentError,
    );
  });
}
