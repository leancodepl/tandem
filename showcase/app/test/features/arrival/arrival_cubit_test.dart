import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late ArrivalCubit arrival;

  setUp(() {
    final berlin = demoTrips().firstWhere((trip) => trip.id == 'berlin');
    final day = const ArrivalDays().of('berlin');
    if (day == null) {
      fail('Berlin has no arrival day.');
    }
    arrival = ArrivalCubit(trip: berlin, day: day);
  });

  tearDown(() => arrival.close());

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

  test('a booked ride shows on the arrival and drops book_ride', () async {
    await arrival.bookRide('train');

    expect(arrival.arrival.rides.last.booked, isNotNull);
    expect(tools(), isNot(contains('book_ride')));
  });

  test('the text to the host says when the booked ride gets there', () async {
    await arrival.bookRide('train');

    final message = arrival.messageHost();

    // WA 379 lands at 08:40, and the S-Bahn is there 62 minutes later.
    expect(message, allOf(contains('08:40'), contains('09:42')));
    expect(tools(), isNot(contains('message_host')));
  });

  test('without a booked ride, the text to the host says an hour after '
      'landing', () {
    // WA 379 lands at 08:40.
    expect(arrival.messageHost(), contains('around 09:40'));
  });

  test('an early check-in has the room ready at 13:00', () {
    arrival.requestEarlyCheckIn();

    expect(arrival.arrival.hotel.roomReady, DateTime(2026, 10, 28, 13));
    expect(tools(), isNot(contains('request_early_check_in')));
  });
}
