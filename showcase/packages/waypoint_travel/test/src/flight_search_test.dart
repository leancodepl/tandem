import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  const flights = FlightSearch();

  test('a flight costs more on a Friday and more again at the weekend', () {
    expect(
      [
        for (final day in [29, 30, 31])
          flights.find('WA 388', DateTime(2026, 10, day))?.fare,
      ],
      [152, 164, 172],
    );
  });

  test('a flight is found by its number as the traveller writes it', () {
    final flight = flights.find(' wa 388 ', DateTime(2026, 10, 29));

    expect(flight?.number, 'WA 388');
    expect(flight?.departs, DateTime(2026, 10, 29, 18, 5));
    expect(flights.find('WA 999', DateTime(2026, 10, 29)), isNull);
  });
}
