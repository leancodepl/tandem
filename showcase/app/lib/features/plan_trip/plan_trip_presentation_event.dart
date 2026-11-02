import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const PlanTripPresentationEvent();

final class const PlanTripPresentationEventBooked(final TripId tripId)
    extends PlanTripPresentationEvent;
