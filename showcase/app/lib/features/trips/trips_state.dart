import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class TripsState(
  List<Trip> trips, {
  Set<TripId> pendingBookings = const {},
}) with Equatable {
  this {
    final ids = <TripId>{};
    for (final trip in trips) {
      if (ids.add(trip.id)) continue;
      throw ArgumentError.value(trip.id, 'trips', 'Duplicate trip id');
    }
  }

  final List<Trip> trips = List.unmodifiable(trips);
  final Set<TripId> pendingBookings = Set.unmodifiable(pendingBookings);

  @override
  List<Object?> get props => [trips, pendingBookings];
}
