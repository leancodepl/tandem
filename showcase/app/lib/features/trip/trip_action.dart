import 'package:waypoint_travel/waypoint_travel.dart';

/// What the agent does to the trip through a method of the trip's cubit,
/// read from the tool name and arguments that Tandem reports. The screen
/// switches on it; no other file names the tools or their arguments.
sealed class const TripAction() {
  /// The action of a call of [tool]. Its [arguments] are known once the
  /// call has run, and missing while it runs.
  static TripAction? of(
    String tool, [
    Map<String, Object?> arguments = const {},
  ]) => switch (tool) {
    'find_flights' => FindFlights(
      origin: arguments.parsed('origin', AirportCode.tryParse),
      destination: arguments.parsed('destination', AirportCode.tryParse),
      date: arguments.parsed('date', DateTime.tryParse),
    ),
    'move_meeting' => MoveMeeting(
      arguments.parsed('meetingId', MeetingId.tryParse),
    ),
    'set_homebound_flight' => const SetHomeboundFlight(),
    'set_hotel_nights' => const SetHotelNights(),
    'book_changes' => const BookChanges(),
    _ => null,
  };
}

final class const FindFlights({
  final AirportCode? origin,
  final AirportCode? destination,
  final DateTime? date,
}) extends TripAction;

final class const MoveMeeting(final MeetingId? meetingId) extends TripAction;

final class const SetHomeboundFlight() extends TripAction;

final class const SetHotelNights() extends TripAction;

final class const BookChanges() extends TripAction;

extension on Map<String, Object?> {
  T? parsed<T>(String key, T? Function(String) parse) => switch (this[key]) {
    final String value => parse(value),
    _ => null,
  };
}
