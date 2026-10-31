import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class ActivityCubit() extends Cubit<ActivityState> {
  this : super(ActivityState([]));

  void add(TripAction action, TripCubit trip, int after) {
    if (_step(action, trip, after) case final step?) {
      emit(ActivityState([...state.steps, step]));
    }
  }

  static AgentStep? _step(TripAction action, TripCubit trip, int after) {
    final itinerary = trip.itinerary;
    return switch (action) {
      MoveMeeting(:final meetingId?) => switch (itinerary.meeting(meetingId)) {
        final meeting? => MeetingMovedStep(
          after,
          meeting: meeting.title,
          start: meeting.start,
        ),
        null => null,
      },
      SetHotelNights() => switch (itinerary.hotel) {
        final hotel? => HotelNightsStep(
          after,
          hotel: hotel.name,
          nights: hotel.nights,
        ),
        null => null,
      },
      FindFlights(:final origin, :final destination, :final date) =>
        FlightsLookedUpStep(
          after,
          origin: origin,
          destination: destination,
          date: date,
        ),
      SetHomeboundFlight() => FlightHomeStep(
        after,
        number: itinerary.homebound.number,
        departs: itinerary.homebound.departs,
      ),
      MoveMeeting() || BookChanges() => null,
    };
  }
}

final class ActivityState(List<AgentStep> steps) with Equatable {
  final List<AgentStep> steps = List.unmodifiable(steps);

  @override
  List<Object?> get props => [steps];
}

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
