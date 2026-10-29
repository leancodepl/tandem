import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/trip/trip_action.dart';

/// The items the assistant changed and the traveller has not touched or
/// booked since: the screen marks them in blue. Not part of what the agent
/// sees, so a mark never invalidates an approval.
final class MarksCubit()
    extends Cubit<MarksState>
    with BlocPresentationMixin<MarksState, MarksPresentationEvent> {
  this : super(const MarksState({}));

  void mark(String id) => emit(MarksState({...state.ids, id}));

  void unmark(String id) => emit(MarksState({...state.ids}..remove(id)));

  void clear() => emit(const MarksState({}));

  /// Marks the item that [action] changed, for the screen to show it.
  void markAction(TripAction action) {
    switch (action) {
      case BookChanges():
        clear();
      case MoveMeeting(:final meetingId?):
        _changed(meetingId);
      case SetHomeboundFlight():
        _changed('homebound');
      case SetHotelNights():
        _changed('hotel');
      case MoveMeeting() || FindFlights():
        break;
    }
  }

  void _changed(String id) {
    mark(id);
    emitPresentation(MarksPresentationEventItemChanged(id));
  }
}

final class const MarksState(final Set<String> ids) with Equatable {
  @override
  List<Object?> get props => [ids];
}

sealed class const MarksPresentationEvent();

/// The agent changed the item [id].
final class const MarksPresentationEventItemChanged(final String id)
    extends MarksPresentationEvent;
