import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';

part 'trip.g.dart';

// The trip as the app keeps it. Prices are whole euros: the demo has no cents.

final class const Flight({
  required final String number,
  required final String from,
  required final String to,
  required final DateTime departs,
  required final DateTime arrives,
  required final int fare,
}) with Equatable {
  @override
  List<Object?> get props => [number, from, to, departs, arrives, fare];

  bool isSameAs(Flight other) =>
      number == other.number && departs == other.departs;
}

@CopyWith()
final class const HotelStay({
  required final String name,
  required final String address,
  required final DateTime checkIn,
  required final int nights,
  required final int nightly,
  required final String confirmation,
}) with Equatable {
  @override
  List<Object?> get props => [
    name,
    address,
    checkIn,
    nights,
    nightly,
    confirmation,
  ];

  DateTime get checkOut => checkIn.add(Duration(days: nights));
}

final class const Meeting({
  required final String id,
  required final String title,
  required final String place,
  required final DateTime start,
  required final DateTime end,
}) with Equatable {
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
final class const Itinerary({
  @CopyWithField(immutable: true) required final Flight outbound,
  required final Flight homebound,
  final HotelStay? hotel,
  required final List<Meeting> meetings,
}) with Equatable {
  @override
  List<Object?> get props => [outbound, homebound, hotel, meetings];

  Meeting? meeting(String id) =>
      meetings.where((meeting) => meeting.id == id).firstOrNull;
}

/// A business trip: where, why and what is booked for it.
@CopyWith()
final class const Trip({
  required final String id,
  required final String city,

  /// What the trip is for, such as a client's workshop, when the traveller
  /// said it.
  final String? purpose,
  required final Itinerary booked,
}) with Equatable {
  @override
  List<Object?> get props => [id, city, purpose, booked];

  /// Whether the trip is over on [day]: its flight home has left.
  bool isPastOn(DateTime day) => booked.homebound.departs.isBefore(day);
}
