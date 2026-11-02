import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  const flights = FlightSearch();

  test('a flight costs more on a Friday and more again at the weekend', () {
    expect(
      [
        for (final day in [29, 30, 31])
          flights
              .find(FlightNumber('WA 388'), DateTime(2026, 10, day))
              ?.fare
              .toInt(),
      ],
      [152, 164, 172],
    );
  });

  test('a flight is found by its number as the traveller writes it', () {
    final flight = flights.find(
      FlightNumber(' wa 388 '),
      DateTime(2026, 10, 29),
    );

    expect(flight?.number, FlightNumber('WA 388'));
    expect(flight?.departs, DateTime(2026, 10, 29, 18, 5));
    expect(
      flights.find(FlightNumber('WA 999'), DateTime(2026, 10, 29)),
      isNull,
    );
  });

  test('flight searches use the travel day of an offset instant', () {
    final input = DateTime.parse('2026-10-29T23:30:00Z');
    final found = flights.find(FlightNumber('WA 388'), input);
    final offered = flights.on(AirportCode('BER'), AirportCode('WAW'), input);

    expect(found?.departs, DateTime(2026, 10, 30, 18, 5));
    expect(found?.fare, wholeMoney(164));
    expect(offered, isNotEmpty);
    expect(
      offered.every(
        (flight) => calendarDay(flight.departs) == DateTime(2026, 10, 30),
      ),
      isTrue,
    );
  });
}
