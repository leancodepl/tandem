import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/arrival.dart';
import 'package:waypoint_travel/src/calendar_day.dart';
import 'package:waypoint_travel/src/trip.dart';
import 'package:waypoint_travel/src/value_objects.dart';

abstract final class Policy() {
  static final maxNightly = wholeMoney(160);

  /// A first meeting that starts before this hour needs a night before it.
  static const morningUntil = 12;

  /// A flight home leaves at least this long after the last meeting ends.
  static const toAirport = Duration(hours: 1);

  static final mealsPerDay = wholeMoney(60);

  /// Why the policy rules out [flight] to a trip with [meetings], or null.
  static PolicyBreach? checkOutbound(Flight flight, List<Meeting> meetings) {
    final first = meetings.fold<Meeting?>(
      null,
      (first, meeting) => first == null || meeting.start.isBefore(first.start)
          ? meeting
          : first,
    );
    if (first == null) return null;

    final needsNight = first.start.hour < morningUntil;
    if (needsNight && calendarDaysBetween(flight.arrives, first.start) < 1) {
      return LandsOnMeetingDay(flight, first);
    }
    if (flight.arrives.add(toAirport).isAfter(first.start)) {
      return LandsTooLate(flight, first);
    }
    return null;
  }

  /// Why the policy rules out [flight] home from a trip with [meetings], or
  /// null.
  static PolicyBreach? checkHomebound(Flight flight, List<Meeting> meetings) {
    final last = meetings.fold<Meeting?>(
      null,
      (last, meeting) =>
          last == null || meeting.end.isAfter(last.end) ? meeting : last,
    );
    if (last == null) return null;

    if (flight.departs.isBefore(last.end.add(toAirport))) {
      return LeavesTooEarly(flight, last);
    }
    return null;
  }

  /// Why the policy rules out a hotel at [nightly] euros a night, or null.
  static PolicyBreach? checkNightly(Money nightly) =>
      nightly > maxNightly ? OverNightly(nightly) : null;

  /// Why the policy rules out paying back [claimed] euros of a meal on a day
  /// whose other meals pay back [claimedThatDay], or null.
  static PolicyBreach? checkMeals({
    required Money claimed,
    required Money claimedThatDay,
  }) {
    final left = mealsPerDay - claimedThatDay;
    return claimed > left ? OverMealsPerDay(left) : null;
  }

  /// Why the policy rules out a ride of [mode] from the airport when the
  /// train gets there at [trainArrives], or null. A taxi is fine when no
  /// train gets there before the meeting at [meetingStarts].
  static PolicyBreach? checkRide(
    RideMode mode, {
    required DateTime? trainArrives,
    required DateTime meetingStarts,
  }) => switch ((mode, trainArrives)) {
    (.taxi, final train?) when !train.isAfter(meetingStarts) => TaxiNotNeeded(
      trainArrives: train,
      meetingStarts: meetingStarts,
    ),
    _ => null,
  };
}

/// What a booking breaks of the company [Policy].
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

/// A taxi, though the train gets the traveller to the meeting in time.
final class const TaxiNotNeeded({
  required final DateTime trainArrives,
  required final DateTime meetingStarts,
}) extends PolicyBreach {
  @override
  List<Object?> get props => [trainArrives, meetingStarts];
}
