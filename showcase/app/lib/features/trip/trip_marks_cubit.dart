import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_item_id.dart';
import 'package:waypoint/features/trip/trip_marks_presentation_event.dart';
import 'package:waypoint/features/trip/trip_marks_state.dart';

/// The items the assistant changed and the traveller has not touched or
/// booked since: the screen marks them in blue. Not part of what the agent
/// sees, so a mark never invalidates an approval.
final class MarksCubit()
    extends Cubit<MarksState>
    with BlocPresentationMixin<MarksState, MarksPresentationEvent> {
  this : super(MarksState({}));

  void mark(TripItemId id) => emit(MarksState({...state.ids, id}));

  void unmark(TripItemId id) => emit(MarksState({...state.ids}..remove(id)));

  void clear() => emit(MarksState({}));

  void markAction(TripAction action, {required Set<TripItemId> unbookedItems}) {
    switch (action) {
      case BookChanges():
        emit(MarksState(state.ids.intersection(unbookedItems)));
      case MoveMeeting(:final meetingId?):
        _changed(.meeting(meetingId));
      case SetHomeboundFlight():
        _changed(.homebound);
      case SetHotelNights():
        _changed(.hotel);
      case MoveMeeting() || FindFlights():
        break;
    }
  }

  void _changed(TripItemId id) {
    mark(id);
    emitPresentation(MarksPresentationEventItemChanged(id));
  }
}
