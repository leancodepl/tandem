import 'package:waypoint_travel/src/trip.dart';
import 'package:waypoint_travel/src/value_objects.dart';

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

  static final _timetable = [
    _Scheduled(
      number: FlightNumber('WA 379'),
      origin: AirportCode('WAW'),
      destination: AirportCode('BER'),
      departs: (7, 15),
      duration: const Duration(minutes: 85),
      fare: wholeMoney(136),
    ),
    _Scheduled(
      number: FlightNumber('WA 381'),
      origin: AirportCode('WAW'),
      destination: AirportCode('BER'),
      departs: (11, 30),
      duration: const Duration(minutes: 85),
      fare: wholeMoney(118),
    ),
    _Scheduled(
      number: FlightNumber('WA 385'),
      origin: AirportCode('WAW'),
      destination: AirportCode('BER'),
      departs: (16, 20),
      duration: const Duration(minutes: 85),
      fare: wholeMoney(149),
    ),
    _Scheduled(
      number: FlightNumber('WA 382'),
      origin: AirportCode('BER'),
      destination: AirportCode('WAW'),
      departs: (7, 5),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(118),
    ),
    _Scheduled(
      number: FlightNumber('WA 386'),
      origin: AirportCode('BER'),
      destination: AirportCode('WAW'),
      departs: (12, 50),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(142),
    ),
    _Scheduled(
      number: FlightNumber('WA 388'),
      origin: AirportCode('BER'),
      destination: AirportCode('WAW'),
      departs: (18, 5),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(152),
    ),
    _Scheduled(
      number: FlightNumber('WA 390'),
      origin: AirportCode('BER'),
      destination: AirportCode('WAW'),
      departs: (20, 45),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(167),
    ),
    _Scheduled(
      number: FlightNumber('WA 471'),
      origin: AirportCode('WAW'),
      destination: AirportCode('CPH'),
      departs: (7, 0),
      duration: const Duration(minutes: 95),
      fare: wholeMoney(158),
    ),
    _Scheduled(
      number: FlightNumber('WA 475'),
      origin: AirportCode('WAW'),
      destination: AirportCode('CPH'),
      departs: (13, 40),
      duration: const Duration(minutes: 95),
      fare: wholeMoney(139),
    ),
    _Scheduled(
      number: FlightNumber('WA 472'),
      origin: AirportCode('CPH'),
      destination: AirportCode('WAW'),
      departs: (12, 30),
      duration: const Duration(minutes: 95),
      fare: wholeMoney(144),
    ),
    _Scheduled(
      number: FlightNumber('WA 478'),
      origin: AirportCode('CPH'),
      destination: AirportCode('WAW'),
      departs: (19, 10),
      duration: const Duration(minutes: 95),
      fare: wholeMoney(171),
    ),
    _Scheduled(
      number: FlightNumber('WA 511'),
      origin: AirportCode('WAW'),
      destination: AirportCode('VIE'),
      departs: (7, 5),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(129),
    ),
    _Scheduled(
      number: FlightNumber('WA 517'),
      origin: AirportCode('WAW'),
      destination: AirportCode('VIE'),
      departs: (17, 40),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(141),
    ),
    _Scheduled(
      number: FlightNumber('WA 519'),
      origin: AirportCode('WAW'),
      destination: AirportCode('VIE'),
      departs: (20, 10),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(112),
    ),
    _Scheduled(
      number: FlightNumber('WA 512'),
      origin: AirportCode('VIE'),
      destination: AirportCode('WAW'),
      departs: (10, 30),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(126),
    ),
    _Scheduled(
      number: FlightNumber('WA 518'),
      origin: AirportCode('VIE'),
      destination: AirportCode('WAW'),
      departs: (18, 45),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(148),
    ),
    _Scheduled(
      number: FlightNumber('WA 520'),
      origin: AirportCode('VIE'),
      destination: AirportCode('WAW'),
      departs: (21, 15),
      duration: const Duration(minutes: 80),
      fare: wholeMoney(117),
    ),
    _Scheduled(
      number: FlightNumber('WA 631'),
      origin: AirportCode('WAW'),
      destination: AirportCode('CDG'),
      departs: (7, 30),
      duration: const Duration(minutes: 150),
      fare: wholeMoney(188),
    ),
    _Scheduled(
      number: FlightNumber('WA 636'),
      origin: AirportCode('CDG'),
      destination: AirportCode('WAW'),
      departs: (19, 20),
      duration: const Duration(minutes: 140),
      fare: wholeMoney(176),
    ),
  ];

  static String airport(AirportCode code) =>
      _airports[code.value] ?? code.value;

  List<Flight> on(
    AirportCode origin,
    AirportCode destination,
    DateTime date,
  ) => [
    for (final scheduled in _timetable)
      if (scheduled.origin == origin && scheduled.destination == destination)
        scheduled.on(date),
  ];

  Flight? find(FlightNumber number, DateTime date) => _timetable
      .where((scheduled) => scheduled.number == number)
      .firstOrNull
      ?.on(date);
}

/// A flight of the timetable, which flies every day.
final class const _Scheduled({
  required final FlightNumber number,
  required final AirportCode origin,
  required final AirportCode destination,
  required final (int, int) departs,
  required final Duration duration,
  required final Money fare,
}) {
  Flight on(DateTime date) {
    final (hour, minute) = departs;
    final at = DateTime(date.year, date.month, date.day, hour, minute);
    final markup = switch (date.weekday) {
      DateTime.friday => wholeMoney(12),
      DateTime.saturday || DateTime.sunday => wholeMoney(20),
      _ => wholeMoney(0),
    };
    return Flight(
      number: number,
      origin: origin,
      destination: destination,
      departs: at,
      arrives: at.add(duration),
      fare: fare + markup,
    );
  }
}
