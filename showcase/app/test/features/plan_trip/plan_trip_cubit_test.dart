import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/plan_trip/plan_trip_cubit.dart';
import 'package:waypoint/features/plan_trip/plan_trip_form_controller.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late TripsCubit trips;
  late PlanTripCubit plan;

  setUp(() {
    trips = TripsCubit(demoTrips(), inbox: const Inbox());
    plan = _planner(trips);
  });

  test('a city that Waypoint does not fly to is refused', () {
    expect(() => plan.setCity('Paris'), throwsA(isA<ToolCallRefused>()));
    expect(plan.form.city.fieldValue, 'Vienna');
  });

  test('a meeting that does not end after it starts is refused', () {
    final noon = DateTime(2026, 12, 10, 12);

    expect(
      () => plan.addMeeting('Lunch', 'Alpenlicht', noon, noon),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test('a hotel waits for both flights, which set its nights', () {
    expect(() => plan.setHotel('spittelberg'), throwsA(isA<ToolCallRefused>()));

    _plan(plan);

    expect(plan.state.nights, 1);
    // WA 517 and WA 518 on weekdays, and a night at the Spittelberg.
    expect(plan.state.total, 141 + 148 + 138);
  });

  test('the trip can be booked once nothing is missing', () {
    expect(plan.ready, isFalse);
    expect(plan.missing, [
      PlanPart.outbound,
      PlanPart.homebound,
      PlanPart.hotel,
    ]);

    _plan(plan);

    expect(plan.ready, isTrue);
  });

  test('a trip home on the day it starts needs no hotel', () {
    final day = DateTime(2026, 12, 9);
    final sameDay = PlanTripState(
      meetings: [
        Meeting(
          id: 'meeting-1',
          title: 'Lunch with Mira',
          place: 'Alpenlicht',
          start: DateTime(2026, 12, 9, 12),
          end: DateTime(2026, 12, 9, 13),
        ),
      ],
      outbound: const FlightSearch().find('WA 511', day),
      homebound: const FlightSearch().find('WA 518', day),
    );

    expect(sameDay.nights, 0);
    expect(sameDay.missingPicks, isEmpty);
  });

  test('a morning meeting needs a flight the evening before', () {
    expect(
      () => plan.setOutboundFlight('WA 511', DateTime(2026, 12, 9)),
      throwsA(isA<ToolCallRefused>()),
    );

    plan.setOutboundFlight('WA 517', DateTime(2026, 12, 8));

    expect(plan.state.outbound?.number, 'WA 517');
  });

  test('a hotel over the policy is refused', () {
    plan
      ..setOutboundFlight('WA 517', DateTime(2026, 12, 8))
      ..setHomeboundFlight('WA 518', DateTime(2026, 12, 9));

    expect(
      () => plan.setHotel('ringstrasse-grand'),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test('the flight home leaves an hour after the meeting that ends last', () {
    plan
      ..addMeeting(
        'Steering group',
        'Alpenlicht',
        DateTime(2026, 12, 9, 10),
        DateTime(2026, 12, 9, 20),
      )
      ..addMeeting(
        'Coffee with Mira',
        'Alpenlicht',
        DateTime(2026, 12, 9, 17),
        DateTime(2026, 12, 9, 17, 30),
      );

    expect(
      () => plan.setHomeboundFlight('WA 518', DateTime(2026, 12, 9)),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test('flights and a hotel outside the city of the trip are refused', () {
    expect(
      () => plan.setOutboundFlight('WA 385', DateTime(2026, 12, 8)),
      throwsA(isA<ToolCallRefused>()),
    );
    expect(
      () => plan.setHomeboundFlight('WA 478', DateTime(2026, 12, 9)),
      throwsA(isA<ToolCallRefused>()),
    );

    plan
      ..setCity('Berlin')
      ..setOutboundFlight('WA 385', DateTime(2026, 12, 8))
      ..setHomeboundFlight('WA 388', DateTime(2026, 12, 9));

    expect(() => plan.setHotel('spittelberg'), throwsA(isA<ToolCallRefused>()));
  });

  test('the search marks what the trip or the policy rules out', () {
    List<String> ruledOut(String origin, String destination, DateTime date) => [
      for (final flight in plan.findFlights(origin, destination, date))
        if (flight.unavailable != null) flight.number,
    ];

    // Each lands on the day of the workshop, which starts at 09:30.
    expect(ruledOut('WAW', 'VIE', DateTime(2026, 12, 9)), [
      'WA 511',
      'WA 517',
      'WA 519',
    ]);
    expect(ruledOut('waw', 'vie', DateTime(2026, 12, 8)), isEmpty);
    expect(ruledOut('VIE', 'WAW', DateTime(2026, 12, 9)), ['WA 512']);
    // Not to Vienna.
    expect(ruledOut('WAW', 'BER', DateTime(2026, 12, 8)), [
      'WA 379',
      'WA 381',
      'WA 385',
    ]);
    expect(
      [
        for (final hotel in plan.findHotels('Vienna'))
          if (hotel.unavailable != null) hotel.id,
      ],
      ['ringstrasse-grand'],
    );
  });

  test('a trip to Berlin over a night is booked with a hotel there', () async {
    plan
      ..setCity('Berlin')
      ..setOutboundFlight('WA 385', DateTime(2026, 12, 8))
      ..setHomeboundFlight('WA 388', DateTime(2026, 12, 9))
      ..setHotel('spree-loft');

    final booked = switch (await _book(plan)) {
      final id? => trips.tripOrNull(id)?.booked,
      null => null,
    };

    expect(booked?.hotel?.name, 'Spree Loft Hotel');
  });

  test("the traveller's city clears the flights and the hotel", () {
    _plan(plan);

    plan.form.city.select('Berlin');

    expect(
      (plan.state.outbound, plan.state.homebound, plan.state.hotel),
      (null, null, null),
    );
    expect(AgentListing.of(plan).seen['plan'], containsPair('city', 'Berlin'));
  });

  test('a meeting added later drops the flight it rules out', () async {
    _plan(plan);

    plan.addMeeting(
      'Breakfast with Mira',
      'Alpenlicht',
      DateTime(2026, 12, 8, 9),
      DateTime(2026, 12, 8, 10),
    );

    expect(plan.state.outbound, isNull);
    expect(await _book(plan), isNull);
  });

  test('planning stops while the trip is booked', () async {
    _plan(plan);

    final booking = _book(plan);

    expect(AgentListing.of(plan).tools, isEmpty);
    expect(await _book(plan), isNull);
    await booking;
  });

  test('the trip is booked as it was when booking began', () async {
    _plan(plan);

    final booking = _book(plan);
    plan.setHomeboundFlight('WA 518', DateTime(2026, 12, 10));
    final booked = switch (await booking) {
      final id? => trips.tripOrNull(id)?.booked,
      null => null,
    };

    expect(booked?.homebound.departs.day, 9);
    expect(booked?.hotel?.nights, 1);
  });

  test('check-in is from 15:00, or an hour after a later landing', () async {
    Future<DateTime?> checkIn(String outbound) async {
      final planner = _planner(trips)
        ..setOutboundFlight(outbound, DateTime(2026, 12, 8))
        ..setHomeboundFlight('WA 518', DateTime(2026, 12, 9))
        ..setHotel('spittelberg');
      return switch (await _book(planner)) {
        final id? => trips.tripOrNull(id)?.booked.hotel?.checkIn,
        null => null,
      };
    }

    // WA 511 lands at 08:25, WA 517 at 19:00.
    expect(await checkIn('WA 511'), DateTime(2026, 12, 8, 15));
    expect(await checkIn('WA 517'), DateTime(2026, 12, 8, 20));
  });

  test(
    "a trip has its invitation's id, any other trip an id of its own",
    () async {
      final invited = _planner(
        trips,
        invitation: const Inbox().invitation('vienna'),
      );
      final again = _planner(trips);
      _plan(plan);
      _plan(invited);
      _plan(again);

      final ids = [await _book(invited), await _book(plan), await _book(again)];

      expect(ids.first, 'vienna');
      expect(ids.toSet(), hasLength(3));
    },
  );
}

/// Books [plan] and gives the id of the trip it booked, or null when it
/// booked nothing.
Future<String?> _book(PlanTripCubit plan) async {
  final ids = <String>[];
  final booked = plan.presentation.listen(
    (event) => switch (event) {
      PlanTripPresentationEventBooked(:final tripId) => ids.add(tripId),
    },
  );
  await plan.book();
  // The event comes in a later microtask than the end of book().
  await Future<void>.delayed(Duration.zero);
  await booked.cancel();
  return ids.singleOrNull;
}

/// Flights and a hotel for the workshop in Vienna, within the policy.
void _plan(PlanTripCubit plan) => plan
  ..setOutboundFlight('WA 517', DateTime(2026, 12, 8))
  ..setHomeboundFlight('WA 518', DateTime(2026, 12, 9))
  ..setHotel('spittelberg');

/// A planner for the trip to Alpenlicht's workshop in Vienna, with its
/// meeting. It closes, and its form goes, when the test ends.
PlanTripCubit _planner(TripsCubit trips, {ForwardedEmail? invitation}) {
  final form = PlanTripFormController();
  final planner = PlanTripCubit(
    trips: trips,
    flights: const FlightSearch(),
    hotels: const HotelSearch(),
    invitation: invitation,
    form: form,
  );
  addTearDown(() async {
    await planner.close();
    form.dispose();
  });
  return planner
    ..setCity('Vienna')
    ..addMeeting(
      'Discovery workshop',
      'Alpenlicht',
      DateTime(2026, 12, 9, 9, 30),
      DateTime(2026, 12, 9, 17),
    );
}
