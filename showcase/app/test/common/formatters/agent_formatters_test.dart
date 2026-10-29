import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';

void main() {
  final friday = DateTime(2026, 10, 30, 18, 5);

  test('a date for the agent has its weekday, and its time if asked', () {
    expect(forAgent(friday), 'Fri 2026-10-30 18:05');
    expect(forAgent(friday, withTime: false), 'Fri 2026-10-30');
    expect(timeForAgent(DateTime(2026, 10, 30, 8, 5)), '08:05');
  });

  test('a day for the agent reads as the screens show it in English', () {
    expect(dayForAgent(friday), 'Fri 30 Oct');
  });

  test('a range of days names its month once when both are in it', () {
    expect(
      dayRangeForAgent(DateTime(2026, 10, 28), friday),
      'Wed 28 – Fri 30 Oct',
    );
    expect(
      dayRangeForAgent(DateTime(2026, 10, 31), DateTime(2026, 11, 2)),
      'Sat 31 Oct – Mon 2 Nov',
    );
  });
}
