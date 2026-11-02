import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_activity.dart';
import 'package:waypoint/features/trip/trip_activity_state.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';

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
