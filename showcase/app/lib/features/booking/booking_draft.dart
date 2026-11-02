import 'package:waypoint_travel/waypoint_travel.dart';

/// A hotel booking as read from its confirmation, before it joins the trip.
final class const BookingDraft({
  final String? hotel,
  final String? address,
  final DateTime? checkIn,
  final DateTime? checkOut,
  final int? totalPrice,
  final String? confirmation,
}) {
  int? get nights => switch ((checkIn, checkOut)) {
    (final from?, final to?) => calendarDaysBetween(from, to),
    _ => null,
  };
}

enum BookingPart() {
  hotel,
  address,
  checkIn,
  checkOut,
  price,
  confirmation,
}
