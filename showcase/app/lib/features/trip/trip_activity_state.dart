import 'package:equatable/equatable.dart';
import 'package:waypoint/features/trip/trip_activity.dart';

final class ActivityState(List<AgentStep> steps) with Equatable {
  final List<AgentStep> steps = List.unmodifiable(steps);

  @override
  List<Object?> get props => [steps];
}
