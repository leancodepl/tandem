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
  this : super(MarksState({}));

  void mark(String id) => emit(MarksState({...state.ids, id}));

  void unmark(String id) => emit(MarksState({...state.ids}..remove(id)));

  void clear() => emit(MarksState({}));

  void markAction(TripAction action, {required Set<String> unbookedItems}) {
    switch (action) {
      case BookChanges():
        emit(MarksState(state.ids.intersection(unbookedItems)));
      case MoveMeeting(:final meetingId?):
        _changed(meetingId.value);
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

final class MarksState(Set<String> ids) with Equatable {
  final Set<String> ids = Set.unmodifiable(ids);

  @override
  List<Object?> get props => [ids];
}

sealed class const MarksPresentationEvent();

final class const MarksPresentationEventItemChanged(final String id)
    extends MarksPresentationEvent;
