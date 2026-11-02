import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/common/dates/days_after.dart';

void main() {
  test('days after a moment count whole days across a month', () {
    expect(daysAfter(DateTime(2026, 10, 31, 18, 5), 1), DateTime(2026, 11));
    expect(daysAfter(DateTime(2026, 11, 1, 7), -1), DateTime(2026, 10, 31));
  });
}
