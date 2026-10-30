import 'package:waypoint_travel/src/trip.dart';

/// The flights Waypoint can book from Warsaw to Berlin, Copenhagen, Vienna
/// and Paris. A real app would
/// ask its travel provider; these fares stay the same on every run.
final class const FlightSearch() {
  static const _airports = {
    'WAW': 'Warsaw Chopin',
    'BER': 'Berlin Brandenburg',
    'CPH': 'Copenhagen Kastrup',
    'VIE': 'Vienna Schwechat',
    'CDG': 'Paris Charles de Gaulle',
  };

  // Number, from, to, departure, minutes in the air, fare in euros.
  static const _timetable = [
    _Scheduled('WA 379', 'WAW', 'BER', (7, 15), 85, 136),
    _Scheduled('WA 381', 'WAW', 'BER', (11, 30), 85, 118),
    _Scheduled('WA 385', 'WAW', 'BER', (16, 20), 85, 149),
    _Scheduled('WA 382', 'BER', 'WAW', (7, 5), 80, 118),
    _Scheduled('WA 386', 'BER', 'WAW', (12, 50), 80, 142),
    _Scheduled('WA 388', 'BER', 'WAW', (18, 5), 80, 152),
    _Scheduled('WA 390', 'BER', 'WAW', (20, 45), 80, 167),
    _Scheduled('WA 471', 'WAW', 'CPH', (7, 0), 95, 158),
    _Scheduled('WA 475', 'WAW', 'CPH', (13, 40), 95, 139),
    _Scheduled('WA 472', 'CPH', 'WAW', (12, 30), 95, 144),
    _Scheduled('WA 478', 'CPH', 'WAW', (19, 10), 95, 171),
    _Scheduled('WA 511', 'WAW', 'VIE', (7, 5), 80, 129),
    _Scheduled('WA 517', 'WAW', 'VIE', (17, 40), 80, 141),
    _Scheduled('WA 519', 'WAW', 'VIE', (20, 10), 80, 112),
    _Scheduled('WA 512', 'VIE', 'WAW', (10, 30), 80, 126),
    _Scheduled('WA 518', 'VIE', 'WAW', (18, 45), 80, 148),
    _Scheduled('WA 520', 'VIE', 'WAW', (21, 15), 80, 117),
    _Scheduled('WA 631', 'WAW', 'CDG', (7, 30), 150, 188),
    _Scheduled('WA 636', 'CDG', 'WAW', (19, 20), 140, 176),
  ];

  static String airport(String code) => _airports[code] ?? code;

  List<Flight> on(String from, String to, DateTime date) => [
    for (final scheduled in _timetable)
      if (scheduled.from == from && scheduled.to == to) scheduled.on(date),
  ];

  Flight? find(String number, DateTime date) {
    final code = number.trim().toUpperCase();
    return _timetable
        .where((scheduled) => scheduled.number == code)
        .firstOrNull
        ?.on(date);
  }
}

/// A flight of the timetable, which flies every day.
final class const _Scheduled(
  final String number,
  final String from,
  final String to,
  final (int, int) departs,
  final int minutes,
  final int fare,
) {
  Flight on(DateTime date) {
    final (hour, minute) = departs;
    final at = DateTime(date.year, date.month, date.day, hour, minute);
    // A later day of the week costs a little more.
    final markup = switch (date.weekday) {
      DateTime.friday => 12,
      DateTime.saturday || DateTime.sunday => 20,
      _ => 0,
    };
    return Flight(
      number: number,
      from: from,
      to: to,
      departs: at,
      arrives: at.add(Duration(minutes: minutes)),
      fare: fare + markup,
    );
  }
}

/// A flight as find_flights gives it to the agent.
final class const FlightOption({
  required final String number,
  required final String departs,
  required final String arrives,
  required final int fare,

  /// Why the traveller cannot take it, or null when they can.
  final String? unavailable,
});
