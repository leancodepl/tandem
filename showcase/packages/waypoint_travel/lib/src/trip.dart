import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/calendar_day.dart';
import 'package:waypoint_travel/src/value_objects.dart';

part 'trip.g.dart';

final class Flight({
  required final FlightNumber number,
  required final AirportCode origin,
  required final AirportCode destination,
  required final DateTime departs,
  required final DateTime arrives,
  required final Money fare,
}) with Equatable {
  this {
    requireSupportedWholeMoney(fare, 'fare');
    if (fare < wholeMoney(0)) {
      throw ArgumentError.value(fare, 'fare', 'Cannot be negative');
    }
    if (arrives.isAfter(departs)) return;
    throw ArgumentError.value(arrives, 'arrives', 'Must be after departure');
  }

  @override
  List<Object?> get props => [
    number,
    origin,
    destination,
    departs,
    arrives,
    fare,
  ];

  bool isSameDepartureAs(Flight other) =>
      number == other.number && departs.isAtSameMomentAs(other.departs);
}

@CopyWith()
final class HotelStay({
  required final String name,
  required final String address,
  required final DateTime checkIn,
  required final NightCount nights,
  required final Money nightly,
  required final BookingReference confirmation,
}) with Equatable {
  this {
    requireSupportedWholeMoney(nightly, 'nightly');
    if (nightly >= wholeMoney(0)) return;
    throw ArgumentError.value(nightly, 'nightly', 'Cannot be negative');
  }

  @override
  List<Object?> get props => [
    name,
    address,
    checkIn,
    nights,
    nightly,
    confirmation,
  ];

  DateTime get checkOut => addCalendarDays(checkIn, nights.value);
}

final class Meeting({
  required final MeetingId id,
  required final String title,
  required final String place,
  required final DateTime start,
  required final DateTime end,
}) with Equatable {
  this {
    if (end.isAfter(start)) return;
    throw ArgumentError.value(end, 'end', 'Must be after the start');
  }

  @override
  List<Object?> get props => [id, title, place, start, end];

  Meeting movedTo(DateTime newStart) => Meeting(
    id: id,
    title: title,
    place: place,
    start: newStart,
    end: newStart.add(end.difference(start)),
  );
}

@CopyWith()
final class const Itinerary._({
  @CopyWithField(immutable: true) required final Flight outbound,
  required final Flight homebound,
  final HotelStay? hotel,
  required final List<Meeting> meetings,
}) with Equatable {
  factory({
    required Flight outbound,
    required Flight homebound,
    HotelStay? hotel,
    required List<Meeting> meetings,
  }) => Itinerary._(
    outbound: outbound,
    homebound: homebound,
    hotel: hotel,
    meetings: List.unmodifiable(meetings),
  );

  @override
  List<Object?> get props => [outbound, homebound, hotel, meetings];

  Meeting? meeting(MeetingId id) =>
      meetings.where((meeting) => meeting.id == id).firstOrNull;
}

@CopyWith()
final class const Trip({
  required final TripId id,
  required final String city,
  final String? purpose,
  required final Itinerary booked,
}) with Equatable {
  @override
  List<Object?> get props => [id, city, purpose, booked];

  bool isPastOn(DateTime day) => booked.homebound.departs.isBefore(day);
}
