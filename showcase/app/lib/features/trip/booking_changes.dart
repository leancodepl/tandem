import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class BookingChanges._(final List<BookingChange> items) with Equatable {
  factory between(Itinerary current, Itinerary booked) => BookingChanges._(
    List.unmodifiable([
      if ((current.hotel, booked.hotel) case (final hotel?, final was?)
          when hotel.nights != was.nights)
        HotelNightsChange(hotel, was: was),
      if (!current.homebound.isSameDepartureAs(booked.homebound))
        FlightHomeChange(current.homebound, was: booked.homebound),
    ]),
  );

  Money get totalCost =>
      items.fold(wholeMoney(0), (sum, change) => sum + change.cost);

  @override
  List<Object?> get props => [items];
}

sealed class const BookingChange() with Equatable {
  String get id;

  Money get cost;
}

final class const HotelNightsChange(
  final HotelStay hotel, {
  required final HotelStay was,
}) extends BookingChange {
  @override
  List<Object?> get props => [hotel, was];

  @override
  String get id => 'hotel';

  @override
  Money get cost => hotel.total - was.total;
}

final class const FlightHomeChange(
  final Flight flight, {
  required final Flight was,
}) extends BookingChange {
  @override
  List<Object?> get props => [flight, was];

  @override
  String get id => 'homebound';

  static final changeFee = wholeMoney(40);

  @override
  Money get cost => flight.fare - was.fare + changeFee;
}
