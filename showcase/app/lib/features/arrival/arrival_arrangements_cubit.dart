import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'arrival_arrangements_cubit.g.dart';

final class ArrivalArrangementsCubit()
    extends Cubit<Map<TripId, ArrivalState>> {
  this : super(const {});

  ArrivalState forTrip(TripId tripId) => state[tripId] ?? const ArrivalState();

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

  void markHostTold(TripId tripId) =>
      _save(tripId, forTrip(tripId).copyWith(hostTold: true));

  void requestEarlyCheckIn(TripId tripId) =>
      _save(tripId, forTrip(tripId).copyWith(earlyCheckIn: true));

  void _save(TripId tripId, ArrivalState arrival) {
    if (isClosed) return;
    emit(Map.unmodifiable({...state, tripId: arrival}));
  }
}

@CopyWith()
final class const ArrivalState({
  final RideBooking? ride,
  final RideId? pendingRide,
  final bool hostTold = false,
  final bool earlyCheckIn = false,
}) with Equatable {
  @override
  List<Object?> get props => [ride, pendingRide, hostTold, earlyCheckIn];
}

final class const RideBooking({
  required final RideId rideId,
  required final BookingReference reference,
}) with Equatable {
  @override
  List<Object?> get props => [rideId, reference];
}
