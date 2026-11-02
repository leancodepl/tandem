import 'package:equatable/equatable.dart';
import 'package:tandem/tandem.dart';

final class ReasksState(Set<String> toolCallIds) with Equatable {
  final Set<String> toolCallIds = Set.unmodifiable(toolCallIds);

  @override
  List<Object?> get props => [toolCallIds];

  bool contains(ApprovalRequest request) =>
      toolCallIds.contains(request.toolCallId);
}
