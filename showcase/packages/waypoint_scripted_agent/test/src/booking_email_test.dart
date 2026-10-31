import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_scripted_agent/src/booking_email.dart';

void main() {
  test('a demo confirmation supplies typed booking fields', () {
    final booking = BookingEmail.tryParse(_confirmation);

    expect(booking?.confirmationNumber, '55120873');
    expect(booking?.hotelName, 'Havnegade Loft');
    expect(booking?.address, 'Havnegade 44, 1058 Copenhagen');
    expect(booking?.checkIn, DateTime(2026, 11, 18, 15));
    expect(booking?.checkOut, DateTime(2026, 11, 19));
    expect(booking?.wholeEuros, 168);
  });

  test('invalid dates and times stay absent instead of rolling over', () {
    for (final text in [
      'Wednesday, 18 Unknown 2026, from 15:00',
      'Wednesday, 31 February 2026, from 15:00',
      'Wednesday, 0 November 2026, from 15:00',
      'Wednesday, 18 November 0000, from 15:00',
      'Wednesday, 18 November 2026, from 25:00',
      'Wednesday, 18 November 2026, from 15:61',
      'Wednesday, 18 November 2026',
    ]) {
      final booking = BookingEmail.tryParse(
        _confirmation.replaceFirst(
          'Wednesday, 18 November 2026, from 15:00',
          text,
        ),
      );

      expect(booking?.checkIn, isNull, reason: text);
      expect(booking?.confirmationNumber, '55120873');
    }
    final leapDay = BookingEmail.tryParse(
      _confirmation.replaceFirst(
        'Thursday, 19 November 2026, by 11:00',
        'Thursday, 29 February 2024, by 11:00',
      ),
    );
    expect(leapDay?.checkOut, DateTime(2024, 2, 29));
  });

  test('whole euro input preserves its precision contract', () {
    for (final total in [
      'EUR 168.50, paid at the hotel',
      'EUR 168.001, paid at the hotel',
      'EUR 0.00',
      'EUR -168.00',
      'USD 168.00',
    ]) {
      final booking = BookingEmail.tryParse(
        _confirmation.replaceFirst('EUR 168.00, paid at the hotel', total),
      );

      expect(booking?.wholeEuros, isNull, reason: total);
      expect(booking?.checkIn, DateTime(2026, 11, 18, 15));
    }
  });

  test('a reference alone does not fabricate an address or dates', () {
    final booking = BookingEmail.tryParse('Confirmation number: 55120873');

    expect(booking?.confirmationNumber, '55120873');
    expect(booking?.address, isNull);
    expect(booking?.checkIn, isNull);
    expect(booking?.checkOut, isNull);
    expect(BookingEmail.tryParse('Confirmation number:  '), isNull);
  });
}

const _confirmation = '''
From: Havnegade Loft <stay@havnegadeloft.example>
Subject: Your booking is confirmed: 55120873

Confirmation number: 55120873
Check-in: Wednesday, 18 November 2026, from 15:00
Check-out: Thursday, 19 November 2026, by 11:00
Total: EUR 168.00, paid at the hotel

Havnegade Loft
Havnegade 44, 1058 Copenhagen''';
