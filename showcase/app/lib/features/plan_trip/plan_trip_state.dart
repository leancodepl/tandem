import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'plan_trip_state.g.dart';

@CopyWith()
final class const PlanTripState._({
  final List<Meeting> meetings = const [],
  final Flight? outbound,
  final Flight? homebound,
  final Hotel? hotel,

  final bool booking = false,

  final Set<PlanTripInput> marked = const {},
}) with Equatable {
  factory({
    List<Meeting> meetings = const [],
    Flight? outbound,
    Flight? homebound,
    Hotel? hotel,
    bool booking = false,
    Set<PlanTripInput> marked = const {},
  }) => ._(
    meetings: List.unmodifiable(meetings),
    outbound: outbound,
    homebound: homebound,
    hotel: hotel,
    booking: booking,
    marked: Set.unmodifiable(marked),
  );

  @override
  List<Object?> get props => [
    meetings,
    outbound,
    homebound,
    hotel,
    booking,
    marked,
  ];

  int? get nights => switch ((outbound, homebound)) {
    (final out?, final home?) => calendarDaysBetween(out.arrives, home.departs),
    _ => null,
  };

  Money get total =>
      (outbound?.fare ?? wholeMoney(0)) +
      (homebound?.fare ?? wholeMoney(0)) +
      (hotel?.nightly ?? wholeMoney(0)) * (nights ?? 0);

  List<PlanPart> get missingPicks => [
    if (meetings.isEmpty) .meetings,
    if (outbound == null) .outbound,
    if (homebound == null) .homebound,
    if (hotel == null && (nights ?? 1) > 0) .hotel,
  ];
}

enum PlanTripInput() {
  city,
  purpose,
}

enum PlanPart(
  /// The part in English, for the agent.
  final String forAgent,
) {
  city('the city'),
  meetings('the meetings'),
  outbound('the flight there'),
  homebound('the flight home'),
  hotel('the hotel'),
}
