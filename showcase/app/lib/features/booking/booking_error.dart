import 'package:equatable/equatable.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';

sealed class const BookingError() with Equatable {
  /// The error in English, for the agent.
  String get forAgent;
}

final class const OutsideTrip(
  final DateTime day, {
  required final DateTime tripStart,
  required final DateTime tripEnd,
}) extends BookingError {
  @override
  List<Object?> get props => [day, tripStart, tripEnd];

  @override
  String get forAgent =>
      '${_dayForAgent(day)} is outside the trip, '
      '${dayRangeForAgent(tripStart, tripEnd)}';
}

final class const CheckInNotBeforeCheckOut(final DateTime checkOut)
    extends BookingError {
  @override
  List<Object?> get props => [checkOut];

  @override
  String get forAgent =>
      'The check-in must be before the check-out, ${_dayForAgent(checkOut)}; '
      'to move the stay later, set the check-out first';
}

final class const CheckOutNotAfterCheckIn(final DateTime checkIn)
    extends BookingError {
  @override
  List<Object?> get props => [checkIn];

  @override
  String get forAgent =>
      'The check-out must be after the check-in, ${_dayForAgent(checkIn)}';
}

final class const PriceNotPositive() extends BookingError {
  @override
  List<Object?> get props => [];

  @override
  String get forAgent => 'The price must be more than 0';
}

/// 2026-10-28
String _dayForAgent(DateTime day) => day.toIso8601String().substring(0, 10);
