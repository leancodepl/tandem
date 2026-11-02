import 'package:waypoint_travel/src/arrival.dart';
import 'package:waypoint_travel/src/value_objects.dart';

/// Arrival-day details are available only for the Berlin trip.
final class const ArrivalDays() {
  ArrivalDay? of(TripId tripId) => switch (tripId.value) {
    'berlin' => ArrivalDay(
      tripId: TripId('berlin'),
      meetingId: MeetingId('kickoff'),
      host: const Host('Lena Kraft', '+49 30 5557 1204'),
      roomReadyEarly: DateTime(2026, 10, 28, 13),
      rides: [
        Ride(
          id: RideId('taxi'),
          mode: .taxi,
          duration: const Duration(minutes: 35),
          fare: wholeMoney(48),
        ),
        Ride(
          id: RideId('train'),
          mode: .train,
          duration: const Duration(minutes: 52),
          fare: wholeMoney(4),
        ),
      ],
    ),
    _ => null,
  };
}
