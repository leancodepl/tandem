import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('a confirmed total is preserved without inventing a nightly quote', () {
    for (final (euros, nights) in [(245, 2), (245, 3), (244, 2)]) {
      final stay = _forTotal(euros, nights);

      expect(stay.total, wholeMoney(euros));
      expect(stay.nightlyRate, isNull);
      expect(() => stay.withNights(NightCount(4)), throwsStateError);
    }
  });

  test('changing quoted nights updates their total together', () {
    final stay = HotelStay.atNightlyRate(
      name: 'Spree Loft Hotel',
      address: 'Am Wriezener Bahnhof 2, Berlin',
      checkIn: DateTime(2026, 10, 28, 15),
      nights: NightCount(2),
      nightlyRate: wholeMoney(122),
      confirmation: BookingReference('84213907'),
    );

    final longer = stay.withNights(NightCount(3));

    expect(stay.total, wholeMoney(244));
    expect(stay.nights, NightCount(2));
    expect(longer.total, wholeMoney(366));
    expect(longer.nights, NightCount(3));
    expect(longer.nightlyRate, wholeMoney(122));
  });

  test(
    'correcting booking details preserves its exact total and quote status',
    () {
      final stay = _forTotal(245, 3);

      final corrected = stay.copyWith(
        name: 'Corrected hotel name',
        checkIn: DateTime(2026, 10, 29, 15),
        confirmation: BookingReference('corrected-reference'),
      );

      expect(corrected.total, wholeMoney(245));
      expect(corrected.nights, NightCount(3));
      expect(corrected.nightlyRate, isNull);
      expect(corrected.checkOut, DateTime(2026, 11, 1, 15));
    },
  );
}

HotelStay _forTotal(int euros, int nights) => HotelStay.forTotal(
  name: 'Spree Loft Hotel',
  address: 'Am Wriezener Bahnhof 2, Berlin',
  checkIn: DateTime(2026, 10, 28, 15),
  nights: NightCount(nights),
  total: wholeMoney(euros),
  confirmation: BookingReference('84213907'),
);
