import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class const TripState({
  required final Itinerary current,
  required final Itinerary booked,
  final bool booking = false,
}) with Equatable {
  TripState withConfirmed(Itinerary latest, {required bool booking}) =>
      TripState(
        current: current.copyWith(
          homebound: _flightWithConfirmedDetails(latest.homebound),
          hotel: _hotelWithConfirmedDetails(latest.hotel),
          meetings: latest.meetings,
        ),
        booked: latest,
        booking: booking,
      );

  Flight _flightWithConfirmedDetails(Flight latest) {
    final draft = current.homebound;
    return draft.isSameDepartureAs(booked.homebound) ||
            draft.isSameDepartureAs(latest)
        ? latest
        : draft;
  }

  HotelStay? _hotelWithConfirmedDetails(HotelStay? latest) {
    final previous = booked.hotel;
    final draft = current.hotel;
    if (latest == null || previous == null || draft == null) return latest;
    if (draft.confirmation != previous.confirmation ||
        latest.confirmation != previous.confirmation) {
      return latest;
    }
    if (draft.nights == previous.nights || latest.nightlyRate == null) {
      return latest;
    }
    return latest.withNights(draft.nights);
  }

  @override
  List<Object?> get props => [current, booked, booking];
}
