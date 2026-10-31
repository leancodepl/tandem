import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('an arrival day owns an immutable snapshot of its rides', () {
    final berlin = const ArrivalDays().of(TripId('berlin'));
    if (berlin == null) fail('Berlin has an arrival day.');
    final rides = [...berlin.rides];
    final day = ArrivalDay(
      tripId: berlin.tripId,
      meetingId: berlin.meetingId,
      host: berlin.host,
      roomReadyEarly: berlin.roomReadyEarly,
      rides: rides,
    );

    rides.clear();

    expect(day.rides, berlin.rides);
    expect(day.rides.clear, throwsUnsupportedError);
  });

  test('a ride id identifies one booking option', () {
    final berlin = const ArrivalDays().of(TripId('berlin'));
    if (berlin == null) fail('Berlin has an arrival day.');
    final taxi = berlin.rides.first;
    final trainWithTaxiId = Ride(
      id: taxi.id,
      mode: .train,
      duration: const Duration(minutes: 52),
      fare: wholeMoney(4),
    );

    expect(
      () => ArrivalDay(
        tripId: berlin.tripId,
        meetingId: berlin.meetingId,
        host: berlin.host,
        roomReadyEarly: berlin.roomReadyEarly,
        rides: [taxi, trainWithTaxiId],
      ),
      throwsArgumentError,
    );
  });
}
