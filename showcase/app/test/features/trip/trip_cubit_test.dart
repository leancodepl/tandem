import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/trip/booking_changes.dart';
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
      info: demoTrips().singleWhere((trip) => trip.id == TripId('berlin')),
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

  test('a flight on another route cannot replace the flight home', () {
    final selected = trip.itinerary.homebound;
    final other = const FlightSearch().find(
      FlightNumber('WA 517'),
      DateTime(2026, 10, 30),
    );
    if (other == null) fail('The timetable has a flight to Vienna.');

    expect(
      () => trip.changeHomeboundFlight(other),
      throwsA(isA<ToolCallRefused>()),
    );
    expect(trip.itinerary.homebound, selected);
  });

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
      [
        for (final change in trip.bookingChanges.items)
          (change.id, change.cost),
      ],
      [('hotel', wholeMoney(122)), ('homebound', wholeMoney(52))],
    );
  });

  test('shortening a stay keeps a negative booking difference', () {
    final hotel = trip.itinerary.hotel;
    if (hotel == null) fail('The Berlin trip has a hotel.');
    final change = HotelNightsChange(
      hotel,
      was: hotel.copyWith(nights: NightCount(2)),
    );

    expect(change.cost, wholeMoney(-122));
  });

  test('invalid flight inputs are refused at the tool boundary', () {
    expect(
      () => trip.setHomeboundFlight('', DateTime(2026, 10, 30)),
      throwsA(isA<ToolCallRefused>()),
    );
    expect(
      () => trip.findFlights('Berlin', 'WAW', DateTime(2026, 10, 30)),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test('booking records the current changes once', () async {
    trip.setHotelNights(2);

    final shown = trip.presentation.first;
    final booking = trip.bookChanges();
    await expectLater(trip.bookChanges(), throwsA(isA<ToolCallRefused>()));
    final booked = await booking;

    expect(booked.charged, 122);
    expect(trip.bookingChanges.items, isEmpty);
    await expectLater(trip.bookChanges(), throwsA(isA<ToolCallRefused>()));
    expect(
      await shown,
      isA<TripPresentationEventChangesBooked>().having(
        (event) => event.confirmation.value,
        'confirmation',
        booked.confirmation,
      ),
    );
  });

  test(
    'editing pending changes keeps one booking and preserves the edit',
    () async {
      trip.setHotelNights(2);
      final booking = trip.bookChanges();

      trip.setHotelNights(3);

      expect(trip.state.booking, isTrue);
      await expectLater(trip.bookChanges(), throwsA(isA<ToolCallRefused>()));
      await booking;

      expect(
        trips.tripOrNull(TripId('berlin'))?.booked.hotel?.nights,
        NightCount(2),
      );
      expect(trip.itinerary.hotel?.nights, NightCount(3));
      expect(trip.bookingChanges.items.single.cost, wholeMoney(122));
      expect(trip.state.booking, isFalse);
    },
  );

  test('a booking still lands when the trip closes before it ends', () async {
    trip.setHotelNights(2);

    final booking = trip.bookChanges();
    await trip.close();
    await booking;

    expect(trips.tripOrNull(TripId('berlin'))?.booked.hotel?.nights.value, 2);
  });

  test(
    'a confirmed hotel survives a pending flight booking and page close',
    () async {
      final copenhagen = TripCubit(
        info: demoTrips().singleWhere(
          (trip) => trip.id == TripId('copenhagen'),
        ),
        trips: trips,
        flights: const FlightSearch(),
        traveller: demoTraveller(),
      );
      addTearDown(copenhagen.close);
      copenhagen.setHomeboundFlight('WA 478', DateTime(2026, 11, 20));
      final flightBooking = copenhagen.bookChanges();
      final hotel = HotelStay(
        name: 'Havnegade Loft',
        address: 'Havnegade 44, 1058 Copenhagen',
        checkIn: DateTime(2026, 11, 18, 15),
        nights: NightCount(2),
        nightly: wholeMoney(168),
        confirmation: BookingReference('55120873'),
      );

      copenhagen.addHotel(hotel);
      await copenhagen.close();
      await flightBooking;

      final booked = trips.tripOrNull(TripId('copenhagen'))?.booked;
      expect(booked?.hotel, hotel);
      expect(booked?.homebound.departs, DateTime(2026, 11, 20, 19, 10));
    },
  );

  test('closing and reopening cannot duplicate a pending booking', () async {
    trip.setHotelNights(2);
    final pending = trip.bookChanges();
    await trip.close();
    final reopened = TripCubit(
      info: trip.info,
      trips: trips,
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
    addTearDown(reopened.close);
    reopened.setHotelNights(3);

    expect(reopened.state.booking, isTrue);
    await expectLater(reopened.bookChanges(), throwsA(isA<ToolCallRefused>()));
    await pending;
    await Future<void>.delayed(Duration.zero);

    expect(reopened.state.booking, isFalse);
    expect(reopened.state.booked.hotel?.nights, NightCount(2));
    expect(reopened.itinerary.hotel?.nights, NightCount(3));
    expect(trips.state.pendingBookings, isEmpty);
  });

  test('moving only a meeting survives closing the trip', () async {
    final movedTo = DateTime(2026, 10, 29, 10);
    trip.moveMeeting('workshop', movedTo);
    await trip.close();
    final reopened = TripCubit(
      info: trip.info,
      trips: trips,
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
    addTearDown(reopened.close);

    expect(reopened.itinerary.meeting(MeetingId('workshop'))?.start, movedTo);
    expect(reopened.bookingChanges.items, isEmpty);
  });

  test('a stale surface adds a hotel to the latest confirmed flight', () async {
    final copenhagenInfo = demoTrips().singleWhere(
      (trip) => trip.id == TripId('copenhagen'),
    );
    TripCubit surface() => TripCubit(
      info: copenhagenInfo,
      trips: trips,
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
    final first = surface();
    final stale = surface();
    addTearDown(first.close);
    addTearDown(stale.close);
    first.setHomeboundFlight('WA 478', DateTime(2026, 11, 20));
    final booking = first.bookChanges();
    first.moveMeeting('review', DateTime(2026, 11, 20, 10));
    await booking;
    final hotel = HotelStay(
      name: 'Havnegade Loft',
      address: 'Havnegade 44, Copenhagen',
      checkIn: DateTime(2026, 11, 18, 15),
      nights: NightCount(2),
      nightly: wholeMoney(168),
      confirmation: BookingReference('55120873'),
    );

    stale.addHotel(hotel);

    final booked = trips.tripOrNull(copenhagenInfo.id)?.booked;
    expect(booked?.hotel, hotel);
    expect(booked?.homebound.departs, DateTime(2026, 11, 20, 19, 10));
    expect(
      booked?.meeting(MeetingId('review'))?.start,
      DateTime(2026, 11, 20, 10),
    );
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
    expect(
      trips.tripOrNull(TripId('berlin'))?.booked.homebound.number.value,
      'WA 388',
    );
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
    'a self-booked hotel is kept and extra nights still obey the policy',
    () {
      final copenhagen = TripCubit(
        info: demoTrips().singleWhere(
          (trip) => trip.id == TripId('copenhagen'),
        ),
        trips: trips,
        flights: const FlightSearch(),
        traveller: demoTraveller(),
      );
      addTearDown(copenhagen.close);
      final stay = HotelStay(
        name: 'Havnegade Loft',
        address: 'Havnegade 44, 1058 Copenhagen',
        checkIn: DateTime(2026, 11, 18, 15),
        nights: NightCount(1),
        nightly: wholeMoney(168),
        confirmation: BookingReference('55120873'),
      );

      expect(copenhagen.warnings, [const NoHotelBooked(1)]);
      expect(
        () => copenhagen.setHotelNights(2),
        throwsA(isA<ToolCallRefused>()),
      );

      copenhagen.addHotel(stay);

      expect(trips.tripOrNull(TripId('copenhagen'))?.booked.hotel, stay);
      expect(copenhagen.bookingChanges.items, isEmpty);
      expect(copenhagen.changesBreach, isNull);
      expect(copenhagen.warnings, isEmpty);

      copenhagen.setHotelNights(2);

      expect(copenhagen.changesBreach, isA<OverNightly>());
      expect(
        AgentListing.of(copenhagen).tools.map((tool) => tool['name']),
        isNot(contains('book_changes')),
      );
      expect(copenhagen.bookChanges(), throwsA(isA<ToolCallRefused>()));
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
