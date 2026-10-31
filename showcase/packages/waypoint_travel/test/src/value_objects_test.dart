import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('airport codes normalize spelling without limiting the provider', () {
    expect(AirportCode(' waw '), AirportCode('WAW'));
    expect(AirportCode('XYZ').value, 'XYZ');
    expect(AirportCode.tryParse('Warsaw'), isNull);
    expect(() => AirportCode('12A'), throwsFormatException);
  });

  test('flight numbers normalize their supported designator format', () {
    expect(FlightNumber(' wa388 '), FlightNumber('WA 388'));
    expect(FlightNumber('u2 42a').value, 'U2 42A');
    expect(FlightNumber.tryParse('WA 12345'), isNull);
    expect(() => FlightNumber('not a flight'), throwsFormatException);
  });

  test(
    'identifiers distinguish their domain and preserve provider spelling',
    () {
      expect(TripId(' berlin '), TripId('berlin'));
      expect(TripId('berlin'), isNot(MeetingId('berlin')));
      expect(BookingReference(' WP-AbC ').value, 'WP-AbC');
      expect(TripId.tryParse('  '), isNull);
      expect(() => MeetingId(''), throwsArgumentError);
      expect(() => HotelId(' '), throwsArgumentError);
      expect(() => RideId(' '), throwsArgumentError);
      expect(() => ReceiptId(' '), throwsArgumentError);
      expect(() => BookingReference(' '), throwsArgumentError);
    },
  );

  test('money calculations preserve signed booking differences', () {
    final cheaperFare = wholeMoney(118);
    final bookedFare = wholeMoney(152);
    final changeFee = wholeMoney(40);
    expect(cheaperFare - bookedFare, wholeMoney(-34));
    expect(cheaperFare - bookedFare + changeFee, wholeMoney(6));
    expect(wholeMoney(122) * -1, wholeMoney(-122));
  });

  test('a hotel night count is positive', () {
    expect(NightCount(2), NightCount(2));
    expect(() => NightCount(0), throwsRangeError);
    expect(() => NightCount(-1), throwsRangeError);
  });
}
