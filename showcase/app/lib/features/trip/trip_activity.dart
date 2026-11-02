import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// One thing the agent did, shown in the thread after the item that was last
/// when it happened.
sealed class const AgentStep(final int after) with Equatable;

final class const MeetingMovedStep(
  super.after, {
  required final String meeting,
  required final DateTime start,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, meeting, start];
}

final class const HotelNightsStep(
  super.after, {
  required final String hotel,
  required final NightCount nights,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, hotel, nights];
}

final class const FlightsLookedUpStep(
  super.after, {
  final AirportCode? origin,
  final AirportCode? destination,
  final DateTime? date,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, origin, destination, date];
}

final class const FlightHomeStep(
  super.after, {
  required final FlightNumber number,
  required final DateTime departs,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, number, departs];
}
