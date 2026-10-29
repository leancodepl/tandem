import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// The approvals the app asked the agent to make again.
final class ReasksCubit() extends Cubit<ReasksState> {
  this : super(const ReasksState({}));

  void add(ApprovalRequest request) =>
      emit(ReasksState({...state.toolCallIds, request.toolCallId}));
}

final class const ReasksState(final Set<String> toolCallIds) with Equatable {
  @override
  List<Object?> get props => [toolCallIds];

  bool contains(ApprovalRequest request) =>
      toolCallIds.contains(request.toolCallId);
}
