import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'arrival_arrangements_cubit.g.dart';

final class ArrivalArrangementsCubit()
    extends Cubit<Map<TripId, ArrivalArrangements>> {
  this : super(const {});

  ArrivalArrangements forTrip(TripId tripId) =>
      state[tripId] ?? const ArrivalArrangements();

  Future<String> bookRide(TripId tripId, Ride ride) async {
    final current = forTrip(tripId);
    if (current.ride != null) throw StateError('A ride is already booked.');
    if (current.pendingRide != null) {
      throw StateError('A ride is being booked.');
    }
    _save(tripId, current.copyWith(pendingRide: ride.id));

    try {
      // Waypoint's showcase books nothing for real.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final (reference, description) = switch (ride.mode) {
        .taxi => ('B-TX 482', 'Taxi B-TX 482, at the rank when you land'),
        .train => ('AB', 'S-Bahn ticket AB, valid for 2 hours'),
      };
      _save(
        tripId,
        forTrip(tripId).copyWith
            .pendingRide(null)
            .copyWith(
              ride: RideBooking(
                rideId: ride.id,
                reference: BookingReference(reference),
              ),
            ),
      );
      return description;
    } finally {
      final latest = forTrip(tripId);
      if (latest.pendingRide == ride.id) {
        _save(tripId, latest.copyWith.pendingRide(null));
      }
    }
  }

  void recordHostMessage(TripId tripId, SentHostMessage message) =>
      _save(tripId, forTrip(tripId).copyWith(hostMessage: message));

  void confirmEarlyCheckIn(TripId tripId, EarlyCheckIn confirmed) =>
      _save(tripId, forTrip(tripId).copyWith(earlyCheckIn: confirmed));

  void _save(TripId tripId, ArrivalArrangements arrival) {
    if (isClosed) return;
    emit(Map.unmodifiable({...state, tripId: arrival}));
  }
}

@CopyWith()
final class const ArrivalArrangements({
  final RideBooking? ride,
  final RideId? pendingRide,
  final SentHostMessage? hostMessage,
  final EarlyCheckIn? earlyCheckIn,
}) with Equatable {
  @override
  List<Object?> get props => [ride, pendingRide, hostMessage, earlyCheckIn];
}

final class const RideBooking({
  required final RideId rideId,
  required final BookingReference reference,
}) with Equatable {
  @override
  List<Object?> get props => [rideId, reference];
}

final class const SentHostMessage({
  required final String phone,
  required final String text,
}) with Equatable {
  @override
  List<Object?> get props => [phone, text];
}

final class const EarlyCheckIn({
  required final BookingReference confirmation,
  required final DateTime roomReady,
}) with Equatable {
  @override
  List<Object?> get props => [confirmation, roomReady];
}
