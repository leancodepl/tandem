import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const TripBookingFailure() implements Exception;

final class const TripBookingUnavailable(final TripBookingProblem problem)
    extends TripBookingFailure;

final class const TripBookingPolicyViolation(final PolicyBreach breach)
    extends TripBookingFailure;

enum TripBookingProblem() {
  alreadyBooking,
  noChanges,
  hotelChanged,
}

extension TripBookingFailureAgentText on TripBookingFailure {
  String get forAgent => switch (this) {
    TripBookingUnavailable(problem: .alreadyBooking) =>
      'The changes are already being booked.',
    TripBookingUnavailable(problem: .noChanges) =>
      'There are no booking changes.',
    TripBookingUnavailable(problem: .hotelChanged) =>
      'The hotel booking changed while these changes were being booked. '
          'Review the current trip before booking again.',
    TripBookingPolicyViolation(:final breach) => '${breach.forAgent}.',
  };
}
