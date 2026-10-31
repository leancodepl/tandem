import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late ArrivalCubit arrival;
  late ArrivalArrangementsCubit arrangements;

  setUp(() {
    arrangements = ArrivalArrangementsCubit();
    final berlin = demoTrips().firstWhere(
      (trip) => trip.id == TripId('berlin'),
    );
    final day = const ArrivalDays().of(TripId('berlin'));
    if (day == null) {
      fail('Berlin has no arrival day.');
    }
    arrival = ArrivalCubit(trip: berlin, day: day, arrangements: arrangements);
  });

  tearDown(() async {
    await arrival.close();
    await arrangements.close();
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
      arrival = ArrivalCubit(trip: trip, day: day, arrangements: arrangements);

      expect(tools(), isNot(contains('book_ride')));
      expect(tools(), isNot(contains('message_host')));
      expect(tools(), isNot(contains('request_early_check_in')));
      await expectLater(
        arrangements.bookRide(trip.id, day.rides.last),
        throwsStateError,
      );
      await booking;

      expect(arrival.arrival.rides.last.booked, isNotNull);
      expect(arrival.arrival.meeting.hostTold, isTrue);
      expect(arrival.arrival.hotel.roomReady, day.roomReadyEarly);
    },
  );

  test('a moved arrival meeting updates the day and its ride policy', () async {
    await arrival.close();
    final trip = demoTrips().singleWhere((trip) => trip.id == TripId('berlin'));
    final day = const ArrivalDays().of(trip.id);
    if (day == null) fail('Berlin has no arrival day.');
    final start = DateTime(2026, 10, 28, 9, 30);
    final moved = trip.copyWith(
      booked: trip.booked.copyWith(
        meetings: [
          for (final meeting in trip.booked.meetings)
            if (meeting.id == day.meetingId)
              meeting.movedTo(start)
            else
              meeting,
        ],
      ),
    );
    arrival = ArrivalCubit(trip: moved, day: day, arrangements: arrangements);

    expect(arrival.arrival.meeting.start, start);
    await arrival.bookRide('taxi');
    expect(arrival.arrival.rides.first.booked, isNotNull);
  });

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
    await arrival.close();
    final trip = demoTrips().singleWhere((trip) => trip.id == TripId('berlin'));
    final withoutHotel = trip.copyWith(
      booked: trip.booked.copyWith.hotel(null),
    );
    final day = const ArrivalDays().of(trip.id);
    if (day == null) fail('Berlin has no arrival day.');
    arrival = ArrivalCubit(
      trip: withoutHotel,
      day: day,
      arrangements: arrangements,
    );

    expect(tools(), isNot(contains('request_early_check_in')));
    expect(arrival.requestEarlyCheckIn, throwsA(isA<ToolCallRefused>()));
    expect(arrival.arrival.hotel.roomReady, isNull);
  });

  test('an early check-in has the room ready at 13:00', () {
    arrival.requestEarlyCheckIn();

    expect(arrival.arrival.hotel.roomReady, DateTime(2026, 10, 28, 13));
    expect(tools(), isNot(contains('request_early_check_in')));
  });
}
