import 'package:equatable/equatable.dart';

/// What a traveller meets after landing, as Waypoint knows it from the trip
/// and the travel provider.
final class const ArrivalDay({
  required final String tripId,

  /// The first meeting after landing.
  required final String meeting,
  required final String meetingPlace,
  required final DateTime meetingStart,

  /// Who expects the traveller at the meeting.
  required final Host host,

  /// When the room is ready if the traveller asks for an early check-in.
  required final DateTime roomReadyEarly,
  required final List<Ride> rides,
}) with Equatable {
  @override
  List<Object?> get props => [
    tripId,
    meeting,
    meetingPlace,
    meetingStart,
    host,
    roomReadyEarly,
    rides,
  ];
}

final class const Host(final String name, final String phone) with Equatable {
  @override
  List<Object?> get props => [name, phone];
}

/// One way from the airport to the meeting.
final class const Ride({
  required final String id,
  required final RideMode mode,
  required final int minutes,

  /// In whole euros.
  required final int fare,
}) with Equatable {
  @override
  List<Object?> get props => [id, mode, minutes, fare];
}

enum RideMode() {
  taxi,

  /// The S-Bahn and a short walk.
  train,
}

/// The arrival days Waypoint knows: Berlin, where Ola lands on Wednesday
/// morning and has the kickoff with Studio Kraft at 11:00.
final class const ArrivalDays() {
  ArrivalDay? of(String tripId) => switch (tripId) {
    'berlin' => ArrivalDay(
      tripId: 'berlin',
      meeting: 'Kickoff with Studio Kraft',
      meetingPlace: 'Studio Kraft, Köpenicker Str. 70',
      meetingStart: DateTime(2026, 10, 28, 11),
      host: const Host('Lena Kraft', '+49 30 5557 1204'),
      roomReadyEarly: DateTime(2026, 10, 28, 13),
      rides: const [
        Ride(id: 'taxi', mode: .taxi, minutes: 35, fare: 48),
        Ride(id: 'train', mode: .train, minutes: 52, fare: 4),
      ],
    ),
    _ => null,
  };
}
