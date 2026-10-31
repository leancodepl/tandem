import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/trip/booking_changes.dart';
import 'package:waypoint/features/trip/trip_action.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_itinerary.dart';
import 'package:waypoint/features/trip/trip_marks_cubit.dart';
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

  test('moving every meeting earlier cannot put the return before arrival', () {
    final selected = trip.itinerary.homebound;
    for (final meeting in trip.itinerary.meetings) {
      trip.moveMeeting(meeting.id.value, DateTime(2026, 10, 26, 9));
    }

    expect(
      () => trip.setHomeboundFlight('WA 388', DateTime(2026, 10, 26)),
      throwsA(isA<ToolCallRefused>()),
    );
    expect(trip.itinerary.homebound, selected);
    expect(
      trip.findFlights('BER', 'WAW', DateTime(2026, 10, 26)),
      everyElement(
        isA<FlightOption>().having(
          (option) => option.unavailable,
          'structural refusal',
          contains('after the flight there lands'),
        ),
      ),
    );
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
      was: hotel.withNights(NightCount(2)),
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

  test('editing pending changes preserves the edit and its mark', () async {
    final marks = MarksCubit()
      ..mark('hotel')
      ..mark('homebound');
    addTearDown(marks.close);
    trip
      ..setHotelNights(2)
      ..setHomeboundFlight('WA 390', DateTime(2026, 10, 29));
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
    marks.markAction(
      const BookChanges(),
      unbookedItems: {
        for (final change in trip.bookingChanges.items) change.id,
      },
    );
    expect(marks.state.ids, {'hotel'});
  });

  test(
    'hotel night edits keep current details and yield to a replacement',
    () async {
      final original = trip.itinerary.hotel;
      if (original == null) fail('The Berlin trip has a hotel.');
      trip.setHotelNights(2);
      final corrected = HotelStay.atNightlyRate(
        name: original.name,
        address: 'Corrected hotel address',
        checkIn: original.checkIn,
        nights: original.nights,
        nightlyRate: wholeMoney(130),
        confirmation: original.confirmation,
      );

      trips.confirmHotel(trip.info.id, corrected);
      await Future<void>.delayed(Duration.zero);

      expect(trip.itinerary.hotel?.nights, NightCount(2));
      expect(trip.itinerary.hotel?.address, corrected.address);
      expect(trip.itinerary.hotel?.nightlyRate, corrected.nightlyRate);
      expect(trip.bookingChanges.totalCost, wholeMoney(130));

      final replacement = corrected
          .copyWith(confirmation: BookingReference('replacement'))
          .withNights(NightCount(3));
      trips.confirmHotel(trip.info.id, replacement);
      await Future<void>.delayed(Duration.zero);

      expect(trip.itinerary.hotel, replacement);
      expect(trip.bookingChanges.items, isEmpty);
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
      final hotel = HotelStay.atNightlyRate(
        name: 'Havnegade Loft',
        address: 'Havnegade 44, 1058 Copenhagen',
        checkIn: DateTime(2026, 11, 18, 15),
        nights: NightCount(2),
        nightlyRate: wholeMoney(168),
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
    final hotel = HotelStay.atNightlyRate(
      name: 'Havnegade Loft',
      address: 'Havnegade 44, Copenhagen',
      checkIn: DateTime(2026, 11, 18, 15),
      nights: NightCount(2),
      nightlyRate: wholeMoney(168),
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

  test(
    'a total-only hotel preserves its price and needs a quote for changes',
    () {
      final previous = trip.itinerary.hotel;
      if (previous == null) fail('The Berlin trip has a hotel.');
      trip.setHotelNights(2);
      final imported = HotelStay.forTotal(
        name: previous.name,
        address: previous.address,
        checkIn: previous.checkIn,
        nights: previous.nights,
        total: wholeMoney(245),
        confirmation: previous.confirmation,
      );
      trip.addHotel(imported);

      expect(trip.itinerary.hotel, imported);
      expect(trip.trip.hotel?.total, 245);
      expect(trip.trip.hotel?.nightly, isNull);
      expect(trip.bookingChanges.items, isEmpty);
      expect(tools(), isNot(contains('set_hotel_nights')));
      expect(() => trip.setHotelNights(3), throwsA(isA<ToolCallRefused>()));
      expect(trip.itinerary.hotel?.total, wholeMoney(245));

      trip.setHomeboundFlight('WA 390', DateTime(2026, 10, 29));
      expect(trip.canBookChanges, isTrue);
    },
  );

  test(
    'a hotel conflict refuses the whole booking and keeps later edits',
    () async {
      final previouslyBooked = trip.state.booked;
      final hotel = previouslyBooked.hotel;
      if (hotel == null) fail('The Berlin trip has a hotel.');
      trip
        ..setHotelNights(2)
        ..setHomeboundFlight('WA 390', DateTime(2026, 10, 29));
      final events = <TripPresentationEvent>[];
      final subscription = trip.presentation.listen(events.add);
      addTearDown(subscription.cancel);
      final booking = trip.bookChanges();
      trip
        ..setHomeboundFlight('WA 388', DateTime(2026, 10, 30))
        ..moveMeeting('kickoff', DateTime(2026, 10, 28, 12));
      final replacement = HotelStay.forTotal(
        name: 'Self-booked replacement',
        address: hotel.address,
        checkIn: hotel.checkIn,
        nights: NightCount(2),
        total: wholeMoney(245),
        confirmation: BookingReference('external-confirmation'),
      );
      trips.confirmHotel(trip.info.id, replacement);

      await expectLater(booking, throwsA(isA<ToolCallRefused>()));
      await Future<void>.delayed(Duration.zero);

      final confirmed = trips.tripOrNull(trip.info.id)?.booked;
      expect(confirmed?.hotel, replacement);
      expect(confirmed?.homebound, previouslyBooked.homebound);
      expect(confirmed?.meeting(MeetingId('kickoff'))?.start.hour, 12);
      expect(trip.itinerary.homebound.departs, DateTime(2026, 10, 30, 18, 5));
      expect(trip.bookingChanges.items.single, isA<FlightHomeChange>());
      expect(trip.state.booking, isFalse);
      expect(events, isEmpty);
    },
  );

  test('a night on the flight does not need a hotel at the destination', () {
    final original = trip.info;
    final booked = Itinerary(
      outbound: Flight(
        number: original.booked.outbound.number,
        origin: original.booked.outbound.origin,
        destination: original.booked.outbound.destination,
        departs: DateTime(2026, 10, 28, 23),
        arrives: DateTime(2026, 10, 29, 6),
        fare: original.booked.outbound.fare,
      ),
      homebound: original.booked.homebound,
      meetings: [
        Meeting(
          id: MeetingId('lunch'),
          title: 'Client lunch',
          place: 'Berlin',
          start: DateTime(2026, 10, 29, 12),
          end: DateTime(2026, 10, 29, 13),
        ),
      ],
    );
    final info = original.copyWith(booked: booked);
    final store = TripsCubit([info], inbox: const Inbox());
    final overnight = TripCubit(
      info: info,
      trips: store,
      flights: const FlightSearch(),
      traveller: demoTraveller(),
    );
    addTearDown(overnight.close);
    addTearDown(store.close);

    expect(overnight.warnings, isEmpty);
    expect(
      planOf(
        booked,
        booked,
      ).expand((day) => day.items).whereType<NoHotelItem>(),
      isEmpty,
    );
  });

  test(
    'a later hotel check-in warns about the first uncovered night',
    () async {
      final hotel = trip.itinerary.hotel;
      if (hotel == null) fail('The Berlin trip has a hotel.');
      trip.setHomeboundFlight('WA 388', DateTime(2026, 10, 30));
      await trip.bookChanges();
      trip.addHotel(hotel.copyWith(checkIn: DateTime(2026, 10, 29, 15)));

      expect(trip.warnings, [NoHotelForNight(DateTime(2026, 10, 28))]);
    },
  );

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
      final stay = HotelStay.atNightlyRate(
        name: 'Havnegade Loft',
        address: 'Havnegade 44, 1058 Copenhagen',
        checkIn: DateTime(2026, 11, 18, 15),
        nights: NightCount(1),
        nightlyRate: wholeMoney(168),
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
