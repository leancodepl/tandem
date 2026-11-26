import 'package:tandem/tandem.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// What the agent does to the trip through a method of the trip's cubit,
/// read from the tool and arguments that Tandem reports. The screen switches
/// on it; no other file reads the arguments.
sealed class const TripAction() {
  /// The action of a call of [tool]. Its [arguments] are known once the
  /// call has run, and missing while it runs.
  static TripAction? of(
    ToolName tool, [
    Map<String, Object?> arguments = const {},
  ]) {
    if (tool is! TripCubitTool) return null;

    return switch (tool) {
      .findFlights => FindFlights(
        origin: arguments.parsed('origin', AirportCode.tryParse),
        destination: arguments.parsed('destination', AirportCode.tryParse),
        date: arguments.parsed(
          'date',
          (date) => DateTime.tryParse(date)?.toLocal(),
        ),
      ),
      .moveMeeting => MoveMeeting(
        arguments.parsed('meetingId', MeetingId.tryParse),
      ),
      .setHomeboundFlight => const SetHomeboundFlight(),
      .setHotelNights => const SetHotelNights(),
      .bookChanges => const BookChanges(),
    };
  }
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
