import 'package:waypoint/features/plan_trip/plan_trip_cubit.dart';
import 'package:waypoint/features/trip/trip_summary.dart';

// What the agent sees of the form: every time with its weekday.

final class const PlanSummary({
  final String? city,
  final String? purpose,
  required final List<MeetingSummary> meetings,
  final FlightSummary? outbound,
  final FlightSummary? homebound,
  final PlannedHotel? hotel,

  /// What the form still needs before the traveller can book it.
  required final List<String> missing,
  required final int total,
}) {
  factory of(
    PlanTripState state, {
    String? city,
    String? purpose,
    required List<PlanPart> missing,
  }) => PlanSummary(
    city: city,
    purpose: purpose,
    meetings: [for (final meeting in state.meetings) .of(meeting)],
    outbound: switch (state.outbound) {
      final flight? => .of(flight),
      null => null,
    },
    homebound: switch (state.homebound) {
      final flight? => .of(flight),
      null => null,
    },
    hotel: switch ((state.hotel, state.nights)) {
      (final hotel?, final nights?) => PlannedHotel(
        name: hotel.name,
        nightly: hotel.nightly,
        nights: nights,
      ),
      _ => null,
    },
    missing: [for (final part in missing) part.forAgent],
    total: state.total,
  );
}

final class const PlannedHotel({
  required final String name,
  required final int nightly,
  required final int nights,
});
