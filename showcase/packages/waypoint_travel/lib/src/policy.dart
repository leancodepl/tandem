import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/arrival.dart';
import 'package:waypoint_travel/src/trip.dart';

/// The traveller's company rules for a trip, which the app enforces and the
/// agent sees.
abstract final class Policy() {
  /// The most a hotel night may cost, in euros.
  static const maxNightly = 160;

  /// A first meeting that starts before this hour needs a night before it.
  static const morningUntil = 12;

  /// A flight home leaves at least this long after the last meeting ends.
  static const toAirport = Duration(hours: 1);

  /// The most meals on one day of a trip pay back, in euros.
  static const mealsPerDay = 60;

  /// The rules for expenses in English, for the agent. The screens say them
  /// in the app's language.
  static const expensesForAgent =
      'Meals are paid back up to €$mealsPerDay a day. Taxis and public '
      'transport are paid back in full. Every expense needs its receipt.';

  /// The rule for the ride from the airport in English, for the agent.
  static const ridesForAgent =
      'A taxi only when public transport would make the traveller late for '
      'the meeting.';

  /// The rules for a trip in English, for the agent.
  static const forAgent =
      'Economy flights. Hotels up to €$maxNightly a night. Arrive the evening '
      'before a meeting that starts before $morningUntil:00. Fly home at '
      'least an hour after the last meeting ends.';

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
    if (needsNight && !_day(flight.arrives).isBefore(_day(first.start))) {
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
  static PolicyBreach? checkNightly(int nightly) =>
      nightly > maxNightly ? OverNightly(nightly) : null;

  /// Why the policy rules out paying back [claimed] euros of a meal on a day
  /// whose other meals pay back [claimedThatDay], or null.
  static PolicyBreach? checkMeals({
    required int claimed,
    required int claimedThatDay,
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

  static DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);
}

/// What a booking breaks of the company [Policy].
sealed class const PolicyBreach() with Equatable {
  /// The breach in English, for the agent.
  String get forAgent;
}

/// The flight there lands on the day of a meeting that starts in the
/// morning.
final class const LandsOnMeetingDay(final Flight flight, final Meeting meeting)
    extends PolicyBreach {
  @override
  List<Object?> get props => [flight, meeting];

  @override
  String get forAgent =>
      '${flight.number} lands on the day of the ${meeting.title}, which '
      'starts before ${Policy.morningUntil}:00';
}

final class const LandsTooLate(final Flight flight, final Meeting meeting)
    extends PolicyBreach {
  @override
  List<Object?> get props => [flight, meeting];

  @override
  String get forAgent =>
      '${flight.number} lands too late for the ${meeting.title}';
}

/// The flight home leaves less than [Policy.toAirport] after [meeting], the
/// one that ends last.
final class const LeavesTooEarly(final Flight flight, final Meeting meeting)
    extends PolicyBreach {
  @override
  List<Object?> get props => [flight, meeting];

  @override
  String get forAgent =>
      '${flight.number} leaves less than an hour after the ${meeting.title} '
      'ends';
}

final class const OverNightly(final int nightly) extends PolicyBreach {
  @override
  List<Object?> get props => [nightly];

  @override
  String get forAgent =>
      'Over the policy: €$nightly a night, the limit is '
      '€${Policy.maxNightly}';
}

/// The meals of one day would pay back more than [Policy.mealsPerDay]: only
/// [left] euros are left for that day.
final class const OverMealsPerDay(final int left) extends PolicyBreach {
  @override
  List<Object?> get props => [left];

  @override
  String get forAgent =>
      'Meals are paid back up to €${Policy.mealsPerDay} a day, and €$left is '
      'left for that day';
}

/// A taxi, though the train gets the traveller to the meeting in time.
final class const TaxiNotNeeded({
  required final DateTime trainArrives,
  required final DateTime meetingStarts,
}) extends PolicyBreach {
  @override
  List<Object?> get props => [trainArrives, meetingStarts];

  @override
  String get forAgent =>
      'The S-Bahn gets the traveller there at ${_time(trainArrives)}, in time '
      'for ${_time(meetingStarts)}: the policy allows a taxi only when public '
      'transport would make them late';
}

String _time(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
