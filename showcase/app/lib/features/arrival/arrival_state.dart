import 'package:equatable/equatable.dart';
import 'package:waypoint/features/arrival/arrival_arrangements.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class const ArrivalState({
  required final Trip trip,
  required final ArrivalArrangements arrangements,
}) with Equatable {
  @override
  List<Object?> get props => [trip, arrangements];
}
