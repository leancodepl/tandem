import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('whole inputs retain euro major units and signed arithmetic', () {
    final rate = wholeMoney(122);

    expect(rate.toInt(), 122);
    expect(rate.minorUnits, BigInt.from(12200));
    expect(rate.currency.isoCode, 'EUR');
    expect(rate * 2, wholeMoney(244));
    expect(rate + wholeMoney(40), wholeMoney(162));
    expect(rate - wholeMoney(160), wholeMoney(-38));
    expect(rate - rate, wholeMoney(0));
    expect(rate > wholeMoney(0), isTrue);
    expect(rate.compareTo(wholeMoney(122)), 0);
  });

  test('package money keeps cent precision and rejects mixed currencies', () {
    final tenCents = Money.fromIntWithCurrency(10, supportedCurrency);
    final twentyCents = Money.fromIntWithCurrency(20, supportedCurrency);
    final dollar = Money.fromNumWithCurrency(1, Currency.create('USD', 2));

    expect((tenCents + twentyCents).minorUnits, BigInt.from(30));
    expect(wholeMoney(1), isNot(dollar));
    expect(() => wholeMoney(1) + dollar, throwsArgumentError);
    expect(() => wholeMoney(1).compareTo(dollar), throwsArgumentError);
  });

  test('domain prices reject fractions and unsupported currencies', () {
    final itinerary = demoTrips().first.booked;
    final flight = itinerary.homebound;
    final hotel = itinerary.hotel;
    if (hotel == null) fail('The first demo trip has a hotel.');

    for (final amount in [
      Money.fromIntWithCurrency(101, supportedCurrency),
      Money.fromNumWithCurrency(1, Currency.create('USD', 2)),
    ]) {
      final owners = <Object Function()>[
        () => Flight(
          number: flight.number,
          origin: flight.origin,
          destination: flight.destination,
          departs: flight.departs,
          arrives: flight.arrives,
          fare: amount,
        ),
        () => HotelStay.atNightlyRate(
          name: hotel.name,
          address: hotel.address,
          checkIn: hotel.checkIn,
          nights: hotel.nights,
          nightlyRate: amount,
          confirmation: hotel.confirmation,
        ),
        () => HotelStay.forTotal(
          name: hotel.name,
          address: hotel.address,
          checkIn: hotel.checkIn,
          nights: hotel.nights,
          total: amount,
          confirmation: hotel.confirmation,
        ),
        () => Hotel(
          id: HotelId('hotel'),
          name: 'Hotel',
          city: 'Paris',
          address: 'Address',
          nightly: amount,
          walkDuration: Duration.zero,
        ),
        () => Ride(
          id: RideId('train'),
          mode: .train,
          duration: const Duration(minutes: 30),
          fare: amount,
        ),
        () => Receipt(
          id: ReceiptId('receipt'),
          merchant: 'Merchant',
          category: .transport,
          day: DateTime(2026, 10, 31),
          paid: amount,
        ),
      ];
      for (final create in owners) {
        expect(create, throwsArgumentError);
      }
    }
  });
}
