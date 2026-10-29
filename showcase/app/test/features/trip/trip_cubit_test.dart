import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late TripsCubit trips;
  late TripCubit trip;

  setUp(() {
    trips = TripsCubit(demoTrips(), inbox: const Inbox());
    trip = TripCubit(
      info: demoTrips().singleWhere((trip) => trip.id == 'berlin'),
      trips: trips,
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
  });

  tearDown(() => trip.close());

  List<String> tools() => [
    for (final tool in AgentListing.of(trip).tools) '${tool['name']}',
  ];

  test(
    'book_changes is offered only once something differs from the booking',
    () {
      expect(tools(), isNot(contains('book_changes')));

      trip.setHotelNights(2);

      expect(tools(), contains('book_changes'));
    },
  );

  test('a flight home before the last meeting ends is refused', () {
    trip.moveMeeting('workshop', DateTime(2026, 10, 30, 10));

    expect(
      () => trip.setHomeboundFlight('WA 386', DateTime(2026, 10, 30)),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test('the changes to book carry the fare difference and the change fee', () {
    trip
      ..moveMeeting('workshop', DateTime(2026, 10, 30, 10))
      ..setHotelNights(2)
      ..setHomeboundFlight('WA 388', DateTime(2026, 10, 30));

    // A night at €122, and €164 on Friday against €152 on Thursday plus €40.
    expect(
      [for (final change in trip.bookingChanges) (change.id, change.cost)],
      [('hotel', 122), ('homebound', 52)],
    );
  });

  test('booking makes the trip on the screen the booked one', () async {
    trip.setHotelNights(2);

    final shown = trip.presentation.first;
    final booked = await trip.bookChanges();

    expect(booked.charged, 122);
    expect(trip.bookingChanges, isEmpty);
    expect(
      await shown,
      isA<TripPresentationEventChangesBooked>().having(
        (event) => event.confirmation,
        'confirmation',
        booked.confirmation,
      ),
    );
  });

  test('a booking still lands when the trip closes before it ends', () async {
    trip.setHotelNights(2);

    final booking = trip.bookChanges();
    await trip.close();
    await booking;

    expect(trips.tripOrNull('berlin')?.booked.hotel?.nights, 2);
  });

  test('the warnings name what no longer fits the moved workshop', () {
    trip.moveMeeting('workshop', DateTime(2026, 10, 30, 10));

    expect(trip.warnings, [
      isA<BreaksPolicy>().having(
        (warning) => warning.breach,
        'breach',
        isA<LeavesTooEarly>(),
      ),
    ]);

    trip.setHomeboundFlight('WA 388', DateTime(2026, 10, 30));

    expect(trip.warnings, [NoHotelForNight(DateTime(2026, 10, 29))]);
  });

  test('a stay is 1 to 14 nights', () {
    for (final nights in [0, 15]) {
      expect(
        () => trip.setHotelNights(nights),
        throwsA(isA<ToolCallRefused>()),
      );
    }
  });

  test('a meeting that is not on the trip cannot move', () {
    expect(
      () => trip.moveMeeting('lunch', DateTime(2026, 10, 29, 12)),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test('a flight home that a later meeting rules out is not booked', () {
    trip
      ..setHomeboundFlight('WA 390', DateTime(2026, 10, 29))
      ..moveMeeting('workshop', DateTime(2026, 10, 29, 20, 15));

    expect(tools(), isNot(contains('book_changes')));
    expect(trip.bookChanges(), throwsA(isA<ToolCallRefused>()));
    expect(trips.tripOrNull('berlin')?.booked.homebound.number, 'WA 388');
  });

  test('the agent reads the unbooked changes in English', () {
    trip
      ..setHotelNights(2)
      ..setHomeboundFlight('WA 390', DateTime(2026, 10, 29));

    expect(
      [
        for (final change in trip.trip.unbookedChanges)
          (change.what, change.now, change.was),
      ],
      [
        ('Spree Loft Hotel, 2 nights', 'Out Fri 30 Oct', '1 night'),
        ('Flight home WA 390', 'Thu 29 Oct, 20:45', 'Thu 29 Oct, 18:05'),
      ],
    );
  });

  test(
    'a trip without a hotel has no nights to set until the traveller adds one',
    () {
      final copenhagen = TripCubit(
        info: demoTrips().singleWhere((trip) => trip.id == 'copenhagen'),
        trips: trips,
        flights: const FlightSearch(),
        traveller: demoTraveller(),
      );
      addTearDown(copenhagen.close);
      final stay = HotelStay(
        name: 'Havnegade Loft',
        address: 'Havnegade 44, 1058 Copenhagen',
        checkIn: DateTime(2026, 11, 18, 15),
        nights: 1,
        nightly: 168,
        confirmation: '55120873',
      );

      expect(copenhagen.warnings, [const NoHotelBooked(1)]);
      expect(
        () => copenhagen.setHotelNights(2),
        throwsA(isA<ToolCallRefused>()),
      );

      copenhagen.addHotel(stay);

      expect(trips.tripOrNull('copenhagen')?.booked.hotel, stay);
      expect(copenhagen.bookingChanges, isEmpty);
      expect(copenhagen.warnings, isEmpty);
    },
  );

  test('find_flights rules out only flights home', () {
    trip.moveMeeting('workshop', DateTime(2026, 10, 30, 10));
    final friday = DateTime(2026, 10, 30);

    List<String> available(String origin, String destination) => [
      for (final flight in trip.findFlights(origin, destination, friday))
        if (flight.unavailable == null) flight.number,
    ];

    expect(available('BER', 'WAW'), ['WA 388', 'WA 390']);
    expect(available('WAW', 'BER'), ['WA 379', 'WA 381', 'WA 385']);
  });
}
