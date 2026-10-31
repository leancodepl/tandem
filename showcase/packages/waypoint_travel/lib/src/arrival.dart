import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/value_objects.dart';

/// What a traveller meets after landing, as Waypoint knows it from the trip
/// and the travel provider.
final class ArrivalDay({
  required final TripId tripId,

  required final MeetingId meetingId,

  /// Who expects the traveller at the meeting.
  required final Host host,

  /// When the room is ready if the traveller asks for an early check-in.
  required final DateTime roomReadyEarly,
  required List<Ride> rides,
}) with Equatable {
  this {
    final ids = <RideId>{};
    for (final ride in rides) {
      if (ids.add(ride.id)) continue;
      throw ArgumentError.value(ride.id, 'rides', 'Duplicate ride id');
    }
  }

  final List<Ride> rides = List.unmodifiable(rides);

  @override
  List<Object?> get props => [tripId, meetingId, host, roomReadyEarly, rides];
}

final class const Host(final String name, final String phone) with Equatable {
  @override
  List<Object?> get props => [name, phone];
}

/// One way from the airport to the meeting.
final class Ride({
  required final RideId id,
  required final RideMode mode,
  required final Duration duration,
  required final Money fare,
}) with Equatable {
  this {
    requireSupportedWholeMoney(fare, 'fare');
    if (fare < wholeMoney(0)) {
      throw ArgumentError.value(fare, 'fare', 'Cannot be negative');
    }
    if (duration >= Duration.zero) return;
    throw ArgumentError.value(duration, 'duration', 'Cannot be negative');
  }

  @override
  List<Object?> get props => [id, mode, duration, fare];
}

enum RideMode() {
  taxi,

  /// The S-Bahn and a short walk.
  train,
}

/// The arrival days Waypoint knows: Berlin, where Ola lands on Wednesday
/// morning and has the kickoff with Studio Kraft at 11:00.
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
