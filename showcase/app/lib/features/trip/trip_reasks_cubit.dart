import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

final class ReasksCubit() extends Cubit<ReasksState> {
  this : super(ReasksState({}));

  void add(ApprovalRequest request) =>
      emit(ReasksState({...state.toolCallIds, request.toolCallId}));
}

final class ReasksState(Set<String> toolCallIds) with Equatable {
  final Set<String> toolCallIds = Set.unmodifiable(toolCallIds);

  @override
  List<Object?> get props => [toolCallIds];

  bool contains(ApprovalRequest request) =>
      toolCallIds.contains(request.toolCallId);
}
