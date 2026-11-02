import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/features/trip/trip_reasks_state.dart';

final class ReasksCubit() extends Cubit<ReasksState> {
  this : super(ReasksState({}));

  void add(ApprovalRequest request) =>
      emit(ReasksState({...state.toolCallIds, request.toolCallId}));
}
