import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const BookingPresentationEvent();

/// The traveller added [stay] to the trip.
final class const BookingPresentationEventAdded(final HotelStay stay)
    extends BookingPresentationEvent;
