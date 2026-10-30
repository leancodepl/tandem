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
      origin: arguments.string('origin'),
      destination: arguments.string('destination'),
      date: switch (arguments.string('date')) {
        final date? => DateTime.tryParse(date),
        null => null,
      },
    ),
    'move_meeting' => MoveMeeting(arguments.string('meetingId')),
    'set_homebound_flight' => const SetHomeboundFlight(),
    'set_hotel_nights' => const SetHotelNights(),
    'book_changes' => const BookChanges(),
    _ => null,
  };
}

final class const FindFlights({
  final String? origin,
  final String? destination,
  final DateTime? date,
}) extends TripAction;

final class const MoveMeeting(final String? meetingId) extends TripAction;

final class const SetHomeboundFlight() extends TripAction;

final class const SetHotelNights() extends TripAction;

final class const BookChanges() extends TripAction;

extension on Map<String, Object?> {
  String? string(String key) => switch (this[key]) {
    final String value => value,
    _ => null,
  };
}
