import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('a calendar day drops the clock and retains UTC or local time', () {
    expect(calendarDay(DateTime(2026, 3, 29, 15)), DateTime(2026, 3, 29));
    expect(
      calendarDay(DateTime.utc(2026, 3, 29, 15)),
      DateTime.utc(2026, 3, 29),
    );
  });

  test('calendar day counts ignore hours and daylight saving changes', () {
    final start = DateTime(2026, 3, 28, 23);
    final end = DateTime(2026, 3, 30, 1);

    expect(calendarDaysBetween(start, end), 2);
    expect(calendarDaysBetween(end, start), -2);
    expect(calendarDaysBetween(start, DateTime(2026, 3, 28)), 0);
    expect(
      calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
      2,
    );
  });

  test('adding calendar days retains the clock fields and UTC flag', () {
    for (final at in [
      DateTime(2026, 3, 28, 15, 20, 30, 456, 789),
      DateTime(2026, 10, 24, 15, 20, 30, 456, 789),
      DateTime.utc(2026, 3, 28, 15, 20, 30, 456, 789),
    ]) {
      final later = addCalendarDays(at, 2);

      expect(
        (later.year, later.month, later.day),
        (at.year, at.month, at.day + 2),
      );
      expect(
        (
          later.hour,
          later.minute,
          later.second,
          later.millisecond,
          later.microsecond,
        ),
        (at.hour, at.minute, at.second, at.millisecond, at.microsecond),
      );
      expect(later.isUtc, at.isUtc);
      expect(addCalendarDays(later, -2), at);
    }
  });
}
