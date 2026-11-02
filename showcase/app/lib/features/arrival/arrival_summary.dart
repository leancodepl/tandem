import 'package:waypoint_travel/waypoint_travel.dart';

final class const ArrivalSummary({
  required final String landing,
  required final MeetingNext meeting,
  required final List<RideSummary> rides,
  required final HotelNext hotel,

  /// The company's rule for rides.
  required final String policy,
});

final class const MeetingNext({
  required final String title,
  required final String place,
  required final DateTime start,
  required final String host,

  /// Whether the traveller texted the host when they arrive.
  required final bool hostTold,
});

final class const RideSummary({
  required final String id,
  required final RideMode mode,
  required final int minutes,

  /// In whole euros.
  required final int fare,
  required final DateTime arrives,

  /// The booking's reference once booked: the taxi's plate or the ticket's
  /// fare zone.
  final String? booked,

  /// Whether the company's rule for rides rules it out.
  required final bool overPolicy,
});

final class const HotelNext({
  /// Null without a hotel booked.
  final String? name,
  final DateTime? checkIn,

  /// When the room is ready, once the traveller asked for an early
  /// check-in.
  final DateTime? roomReady,
});
