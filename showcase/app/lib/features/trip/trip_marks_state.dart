import 'package:equatable/equatable.dart';
import 'package:waypoint/features/trip/trip_item_id.dart';

final class MarksState(Set<TripItemId> ids) with Equatable {
  final Set<TripItemId> ids = Set.unmodifiable(ids);

  @override
  List<Object?> get props => [ids];
}
