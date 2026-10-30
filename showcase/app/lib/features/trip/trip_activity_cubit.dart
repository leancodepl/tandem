import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';

/// The agent's steps, from what it did to the trip.
final class ActivityCubit() extends Cubit<ActivityState> {
  this : super(const ActivityState([]));

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

final class const ActivityState(final List<AgentStep> steps) with Equatable {
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
  required final int nights,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, hotel, nights];
}

/// The agent looked up flights, on a route and day once its call has run.
final class const FlightsLookedUpStep(
  super.after, {
  final String? origin,
  final String? destination,
  final DateTime? date,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, origin, destination, date];
}

final class const FlightHomeStep(
  super.after, {
  required final String number,
  required final DateTime departs,
}) extends AgentStep {
  @override
  List<Object?> get props => [after, number, departs];
}
