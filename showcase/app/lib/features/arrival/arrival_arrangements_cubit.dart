import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/arrival/arrival_arrangements.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

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
