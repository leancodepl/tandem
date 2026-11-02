import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('offset instants become travel clock fields across dates and DST', () {
    for (final (input, expected) in [
      ('2026-12-09T12:30:00+01:00', DateTime(2026, 12, 9, 12, 30)),
      ('2026-12-09T17:00:00Z', DateTime(2026, 12, 9, 18)),
      ('2026-12-09T23:30:00Z', DateTime(2026, 12, 10, 0, 30)),
      ('2026-12-09T00:30:00+03:00', DateTime(2026, 12, 8, 22, 30)),
      ('2026-03-29T00:30:00Z', DateTime(2026, 3, 29, 1, 30)),
      ('2026-03-29T01:30:00Z', DateTime(2026, 3, 29, 3, 30)),
      ('2026-10-25T00:30:00Z', DateTime(2026, 10, 25, 2, 30)),
      ('2026-10-25T01:30:00Z', DateTime(2026, 10, 25, 2, 30)),
      (
        '2026-07-09T12:30:00.123456+02:00',
        DateTime(2026, 7, 9, 12, 30, 0, 123, 456),
      ),
    ]) {
      final converted = travelDateTime(DateTime.parse(input));

      expect(converted, expected, reason: input);
      expect(converted.isUtc, isFalse, reason: input);
    }
    final civil = DateTime(2026, 12, 9, 12, 30, 0, 123, 456);
    expect(identical(travelDateTime(civil), civil), isTrue);
  });

  test('a device DST gap cannot silently shift a valid travel time', () {
    final input = DateTime.parse('2026-03-08T01:30:00Z');
    final native = DateTime(2026, 3, 8, 2, 30);

    if (native.day == 8 && native.hour == 2 && native.minute == 30) {
      expect(travelDateTime(input), native);
    } else {
      expect(() => travelDateTime(input), throwsArgumentError);
    }
  });
}
