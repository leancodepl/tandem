import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

List<TripWarning> tripWarnings(Itinerary itinerary) {
  final hotel = itinerary.hotel;
  final home = calendarDay(itinerary.homebound.departs);
  final out = calendarDay(itinerary.outbound.arrives);
  final nights = calendarDaysBetween(out, home);
  return [
    if (hotel != null && nights > 0) ...[
      if (calendarDaysBetween(out, hotel.checkIn) > 0) NoHotelForNight(out),
      if (calendarDaysBetween(hotel.checkOut, home) > 0)
        NoHotelForNight(
          calendarDaysBetween(hotel.checkOut, out) > 0
              ? out
              : calendarDay(hotel.checkOut),
        ),
    ],
    if (hotel == null && nights > 0) NoHotelBooked(nights),
    if (Policy.checkHomebound(itinerary.homebound, itinerary.meetings)
        case final breach?)
      BreaksPolicy(breach),
  ];
}

sealed class const TripWarning() with Equatable;

final class const NoHotelForNight(final DateTime night) extends TripWarning {
  @override
  List<Object?> get props => [night];
}

final class const NoHotelBooked(final int nights) extends TripWarning {
  @override
  List<Object?> get props => [nights];
}

final class const BreaksPolicy(final PolicyBreach breach) extends TripWarning {
  @override
  List<Object?> get props => [breach];
}
