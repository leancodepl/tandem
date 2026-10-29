import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/demo.dart';

void main() {
  final berlin = demoTrips().singleWhere((trip) => trip.id == 'berlin');

  test('a trip is past once its flight home has left', () {
    expect(berlin.isPastOn(DateTime(2026, 10, 29)), isFalse);
    expect(berlin.isPastOn(DateTime(2026, 10, 30)), isTrue);
  });

  test('a moved meeting keeps its length', () {
    final workshop = berlin.booked.meeting('workshop');

    final moved = workshop?.movedTo(DateTime(2026, 10, 30, 9));

    expect(moved?.end, DateTime(2026, 10, 30, 15));
  });
}
