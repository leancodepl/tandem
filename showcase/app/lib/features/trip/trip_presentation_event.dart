import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const TripPresentationEvent();

final class const TripPresentationEventChangesBooked(
  final BookingReference confirmation,
) extends TripPresentationEvent;
