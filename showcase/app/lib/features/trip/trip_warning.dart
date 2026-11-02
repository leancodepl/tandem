import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const TripWarning() with Equatable;

final class const NoHotelForNight(final DateTime night) extends TripWarning {
  @override
  List<Object?> get props => [night];
}

final class const NoHotelBooked(final int nights) extends TripWarning {
  @override
  List<Object?> get props => [nights];
}

final class const BreaksPolicy(final PolicyBreach breach) extends TripWarning {
  @override
  List<Object?> get props => [breach];
}
