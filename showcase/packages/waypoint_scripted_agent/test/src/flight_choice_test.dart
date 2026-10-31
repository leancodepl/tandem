import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/src/flight_choice.dart';

void main() {
  test(
    'a script skips refused and malformed departures before choosing a flight',
    () {
      final options = [
        {
          'number': 'WA 382',
          'departs': 'Fri 2026-10-30 07:05',
          'unavailable': 'Too early',
        },
        {'number': 'WA 386', 'departs': 'not a departure', 'unavailable': null},
        {
          'number': 'WA 386',
          'departs': 'Fri 2026-10-30 18',
          'unavailable': null,
        },
        {
          'number': 'WA 386',
          'departs': 'Fri 2026-10-30 25:05',
          'unavailable': null,
        },
        {
          'number': 'WA 388',
          'departs': 'Fri 2026-10-30 18:05',
          'unavailable': null,
        },
      ];

      final flight = FlightChoice.allowed(options).single;

      expect(flight.number, 'WA 388');
      expect(flight.departs.hour, 18);
      expect(flight.dateArgument, '2026-10-30');
    },
  );
}
