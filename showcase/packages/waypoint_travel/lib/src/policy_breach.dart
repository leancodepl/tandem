import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/policy.dart';
import 'package:waypoint_travel/src/trip.dart';
import 'package:waypoint_travel/src/value_objects.dart';

sealed class const PolicyBreach() with Equatable;

/// The flight there lands on the day of a meeting that starts in the
/// morning.
final class const LandsOnMeetingDay(final Flight flight, final Meeting meeting)
    extends PolicyBreach {
  @override
  List<Object?> get props => [flight, meeting];
}

final class const LandsTooLate(final Flight flight, final Meeting meeting)
    extends PolicyBreach {
  @override
  List<Object?> get props => [flight, meeting];
}

/// The flight home leaves less than [Policy.toAirport] after [meeting], the
/// one that ends last.
final class const LeavesTooEarly(final Flight flight, final Meeting meeting)
    extends PolicyBreach {
  @override
  List<Object?> get props => [flight, meeting];
}

final class const OverNightly(final Money nightly) extends PolicyBreach {
  @override
  List<Object?> get props => [nightly];
}

/// The meals of one day would pay back more than [Policy.mealsPerDay]: only
/// [left] euros are left for that day.
final class const OverMealsPerDay(final Money left) extends PolicyBreach {
  @override
  List<Object?> get props => [left];
}

final class const TaxiNotNeeded({
  required final DateTime trainArrives,
  required final DateTime meetingStarts,
}) extends PolicyBreach {
  @override
  List<Object?> get props => [trainArrives, meetingStarts];
}
