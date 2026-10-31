import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late ArrivalCubit arrival;
  late ArrivalArrangementsCubit arrangements;
  late TripsCubit trips;

  setUp(() {
    arrangements = ArrivalArrangementsCubit();
    trips = TripsCubit(demoTrips(), inbox: const Inbox());
    final berlin = demoTrips().firstWhere(
      (trip) => trip.id == TripId('berlin'),
    );
    final day = const ArrivalDays().of(TripId('berlin'));
    if (day == null) {
      fail('Berlin has no arrival day.');
    }
    arrival = ArrivalCubit(
      tripId: berlin.id,
      trips: trips,
      day: day,
      arrangements: arrangements,
    );
  });

  tearDown(() async {
    await arrival.close();
    await arrangements.close();
    await trips.close();
  });

  List<String> tools() => [
    for (final tool in AgentListing.of(arrival).tools) '${tool['name']}',
  ];

  test('a taxi is refused while the S-Bahn is in time for the meeting', () {
    expect(
      () => arrival.bookRide('taxi'),
      throwsA(
        isA<ToolCallRefused>().having(
          (refusal) => refusal.message,
          'message',
          contains('09:42'),
        ),
      ),
    );
  });

  test('a ride can only be booked once, including while pending', () async {
    final booking = arrival.bookRide('train');

    expect(tools(), isNot(contains('book_ride')));
    await expectLater(
      arrival.bookRide('train'),
      throwsA(isA<ToolCallRefused>()),
    );
    await booking;

    expect(arrival.arrival.rides.last.booked, isNotNull);
    expect(tools(), isNot(contains('book_ride')));
    await expectLater(
      arrival.bookRide('train'),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test(
    'arrival arrangements survive reopening during a ride booking',
    () async {
      final trip = arrival.trip;
      final day = arrival.day;
      arrival
        ..messageHost()
        ..requestEarlyCheckIn();
      final booking = arrival.bookRide('train');

      await arrival.close();
      arrival = ArrivalCubit(
        tripId: trip.id,
        trips: trips,
        day: day,
        arrangements: arrangements,
      );

      expect(tools(), isNot(contains('book_ride')));
      expect(tools(), isNot(contains('message_host')));
      expect(tools(), isNot(contains('request_early_check_in')));
      await expectLater(
        arrangements.bookRide(trip.id, day.rides.last),
        throwsStateError,
      );
      await booking;

      expect(arrival.arrival.rides.last.booked, isNotNull);
      expect(arrival.arrival.meeting.hostTold, isFalse);
      expect(tools(), contains('message_host'));
      expect(arrangements.forTrip(trip.id).hostMessage, isNotNull);
      expect(arrival.arrival.hotel.roomReady, day.roomReadyEarly);
    },
  );

  test(
    'a moved arrival meeting updates the active day and its ride policy',
    () async {
      final start = DateTime(2026, 10, 28, 9, 30);
      trips.moveMeeting(arrival.tripId, arrival.meeting.movedTo(start));
      await Future<void>.delayed(Duration.zero);

      expect(arrival.arrival.meeting.start, start);
      expect(
        arrival.state.trip.booked.meeting(arrival.day.meetingId)?.start,
        start,
      );
      await arrival.bookRide('taxi');
      expect(arrival.arrival.rides.first.booked, isNotNull);
    },
  );

  test(
    'host and hotel acknowledgements apply only to what was arranged',
    () async {
      arrival
        ..messageHost()
        ..requestEarlyCheckIn();
      expect(arrival.arrival.meeting.hostTold, isTrue);
      final original = arrival.trip.booked.hotel;
      if (original == null) fail('The Berlin trip has a hotel.');
      final replacement = original.copyWith(
        name: 'Other hotel',
        confirmation: BookingReference('other-booking'),
      );
      trips
        ..confirmHotel(arrival.tripId, replacement)
        ..moveMeeting(
          arrival.tripId,
          arrival.meeting.movedTo(
            arrival.meeting.start.add(const Duration(days: 1)),
          ),
        );
      await Future<void>.delayed(Duration.zero);

      expect(arrival.arrival.hotel.roomReady, isNull);
      expect(arrival.arrival.meeting.hostTold, isFalse);
      expect(tools(), containsAll(['message_host', 'request_early_check_in']));
      arrival.requestEarlyCheckIn();
      expect(
        arrangements.forTrip(arrival.tripId).earlyCheckIn?.confirmation,
        replacement.confirmation,
      );
    },
  );

  test(
    'a pending ride blocks a host message with an unfinished arrival time',
    () async {
      final booking = arrival.bookRide('train');

      expect(tools(), isNot(contains('message_host')));
      expect(arrival.messageHost, throwsA(isA<ToolCallRefused>()));
      await booking;
      expect(tools(), contains('message_host'));
    },
  );

  test('the text to the host says when the booked ride gets there', () async {
    await arrival.bookRide('train');

    final message = arrival.messageHost();

    // WA 379 lands at 08:40, and the S-Bahn is there 62 minutes later.
    expect(message, allOf(contains('08:40'), contains('09:42')));
    expect(tools(), isNot(contains('message_host')));
    expect(arrival.messageHost, throwsA(isA<ToolCallRefused>()));
  });

  test('without a booked ride, the text to the host says an hour after '
      'landing', () {
    // WA 379 lands at 08:40.
    expect(arrival.messageHost(), contains('around 09:40'));
  });

  test('an early check-in needs a hotel booking', () async {
    trips.book(arrival.tripId, arrival.trip.booked.copyWith.hotel(null));
    await Future<void>.delayed(Duration.zero);

    expect(tools(), isNot(contains('request_early_check_in')));
    expect(arrival.requestEarlyCheckIn, throwsA(isA<ToolCallRefused>()));
    expect(arrival.arrival.hotel.roomReady, isNull);
  });

  test('an early check-in has the room ready at 13:00', () {
    arrival.requestEarlyCheckIn();

    expect(arrival.arrival.hotel.roomReady, DateTime(2026, 10, 28, 13));
    expect(tools(), isNot(contains('request_early_check_in')));
  });

  test(
    'early check-in is unavailable when the hotel starts on another day',
    () async {
      final booked = arrival.trip.booked;
      final hotel = booked.hotel;
      if (hotel == null) fail('The Berlin trip has a hotel.');
      final homebound = const FlightSearch().find(
        FlightNumber('WA 388'),
        DateTime(2026, 10, 30),
      );
      if (homebound == null) fail('The flight home is in the timetable.');
      trips
        ..book(arrival.tripId, booked.copyWith(homebound: homebound))
        ..confirmHotel(
          arrival.tripId,
          hotel.copyWith(checkIn: addCalendarDays(hotel.checkIn, 1)),
        );
      await Future<void>.delayed(Duration.zero);

      expect(arrival.arrival.hotel.roomReady, isNull);
      expect(tools(), isNot(contains('request_early_check_in')));
      expect(arrival.requestEarlyCheckIn, throwsA(isA<ToolCallRefused>()));
    },
  );
}
