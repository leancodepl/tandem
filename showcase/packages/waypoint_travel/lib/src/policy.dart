import 'package:waypoint_travel/src/arrival.dart';
import 'package:waypoint_travel/src/calendar_day.dart';
import 'package:waypoint_travel/src/policy_breach.dart';
import 'package:waypoint_travel/src/trip.dart';
import 'package:waypoint_travel/src/value_objects.dart';

abstract final class Policy() {
  static final maxNightly = wholeMoney(160);

  /// A first meeting that starts before this hour needs a night before it.
  static const morningUntil = 12;

  /// A flight home leaves at least this long after the last meeting ends.
  static const toAirport = Duration(hours: 1);

  static final mealsPerDay = wholeMoney(60);

  static PolicyBreach? checkOutbound(Flight flight, List<Meeting> meetings) {
    final first = meetings.fold<Meeting?>(
      null,
      (first, meeting) => first == null || meeting.start.isBefore(first.start)
          ? meeting
          : first,
    );
    if (first == null) return null;

    if (flight.arrives.add(toAirport).isAfter(first.start)) {
      return LandsTooLate(flight, first);
    }
    final needsNight = first.start.hour < morningUntil;
    if (needsNight && calendarDaysBetween(flight.arrives, first.start) < 1) {
      return LandsOnMeetingDay(flight, first);
    }
    return null;
  }

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

  static PolicyBreach? checkNightly(Money nightly) =>
      nightly > maxNightly ? OverNightly(nightly) : null;

  /// [claimedThatDay] excludes the current meal.
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
