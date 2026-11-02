import 'dart:async';

import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint/common/tandem/flight_option.dart';
import 'package:waypoint/common/tandem/form_changes.dart';
import 'package:waypoint/features/plan_trip/hotel_option.dart';
import 'package:waypoint/features/plan_trip/plan_trip_form_controller.dart';
import 'package:waypoint/features/plan_trip/plan_trip_presentation_event.dart';
import 'package:waypoint/features/plan_trip/plan_trip_refusal.dart';
import 'package:waypoint/features/plan_trip/plan_trip_state.dart';
import 'package:waypoint/features/plan_trip/plan_trip_summary.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_state.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'plan_trip_cubit.g.dart';

final _log = Logger('PlanTrip');

final _home = AirportCode('WAW');

@TandemAgent()
class PlanTripCubit({
  required final TripsCubit trips,
  required final FlightSearch flights,
  required final HotelSearch hotels,

  final ForwardedEmail? invitation,
  @override required final PlanTripFormController form,
}) extends Cubit<PlanTripState>
    with
        _$PlanTripCubit,
        BlocPresentationMixin<PlanTripState, PlanTripPresentationEvent>,
        FormChanges<PlanTripState> {
  this
    : super(
        PlanTripState(
          booking: switch (invitation?.tripId) {
            final id? =>
              trips.state.pendingBookings.contains(id) ||
                  trips.tripOrNull(id) != null,
            null => false,
          },
        ),
      ) {
    form.addRelation(form.city, (city) => city, (_) => _refit());
    _bookings = trips.stream.listen((_) => _synchronizeInvitation());
    if (state.booking) form.markReadOnly();
    scheduleMicrotask(_synchronizeInvitation);
  }

  late final StreamSubscription<TripsState> _bookings;
  TripId? _notifiedBookedTrip;

  void _synchronizeInvitation() {
    if (isClosed) return;
    final id = invitation?.tripId;
    if (id == null) return;
    if (trips.tripOrNull(id) != null) {
      _showBooked(id);
      return;
    }
    final booking = trips.state.pendingBookings.contains(id);
    if (booking == state.booking) return;
    emit(state.copyWith(booking: booking));
    if (booking) {
      form.markReadOnly();
    } else {
      form.unmarkReadOnly();
    }
  }

  void _showBooked(TripId id) {
    if (isClosed || _notifiedBookedTrip == id) return;
    _notifiedBookedTrip = id;
    emit(state.copyWith(booking: true));
    form.markReadOnly();
    emitPresentation(PlanTripPresentationEventBooked(id));
  }

  @override
  Future<void> close() async {
    await _bookings.cancel();
    await super.close();
  }

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(plan),
    .sees(policy),
    if (!state.booking) ...[
      .calls(setCity),
      .calls(setPurpose),
      .calls(addMeeting),
      .calls(findFlights),
      .calls(setOutboundFlight),
      .calls(setHomeboundFlight),
      .calls(findHotels),
      .calls(setHotel),
    ],
  ];

  /// The new trip as the traveller sees it in the form, with what is still
  /// missing.
  PlanSummary get plan => PlanSummary.of(
    state,
    city: form.city.fieldValue,
    purpose: _purpose,
    missing: missing,
  );

  /// The company's rules for every trip.
  String get policy => PolicyAgentText.trip;

  /// Sets the city of the trip: Berlin, Copenhagen or Vienna.
  void setCity(String city) {
    final known = form.city.options
        .where((name) => name.toLowerCase() == city.trim().toLowerCase())
        .firstOrNull;
    if (known == null) {
      _refuse('Waypoint flies only to Berlin, Copenhagen and Vienna.');
    }
    _requireInvitationCity(known);
    form.city.select(known);
    _mark(.city);
  }

  /// Sets what the trip is for, such as "Discovery · Alpenlicht".
  void setPurpose(String purpose) {
    form.purpose.setValue(purpose);
    _mark(.purpose);
  }

  /// Adds a meeting of the trip, from [start] to [end], at [place].
  void addMeeting(String title, String place, DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      _refuse('A meeting ends after it starts.');
    }
    final meeting = Meeting(
      id: MeetingId('meeting-${state.meetings.length + 1}'),
      title: title,
      place: place,
      start: start,
      end: end,
    );
    emit(
      _fitted(
        state.copyWith(
          meetings: [...state.meetings, meeting]
            ..sort((a, b) => a.start.compareTo(b.start)),
        ),
      ),
    );
  }

  // `origin`, not `from`: ag-ui-adk names the parameters in Python.
  /// Finds the flights from [origin] to [destination] on [date], with their
  /// fares in euros and why the trip or the policy rules one out. Airports
  /// are IATA codes: WAW for Warsaw, BER, CPH and VIE for the trip's city.
  List<FlightOption> findFlights(
    String origin,
    String destination,
    DateTime date,
  ) {
    final originCode = AirportCode.tryParse(origin);
    final destinationCode = AirportCode.tryParse(destination);
    if (originCode == null || destinationCode == null) {
      _refuse('Use three-letter airport codes, such as WAW and VIE.');
    }
    return [
      for (final flight in flights.on(originCode, destinationCode, date))
        FlightOption(
          number: flight.number.value,
          departs: forAgent(flight.departs),
          arrives: forAgent(flight.arrives),
          fare: flight.fare.toInt(),
          unavailable: _flightRefusal(flight, state)?.forAgent,
        ),
    ];
  }

  /// Puts the traveller on flight [number] from Warsaw on [date], one that
  /// find_flights gives.
  void setOutboundFlight(String number, DateTime date) {
    final flight = _findFlight(number, date);
    if (_outboundRefusal(flight, state) case final refusal?) {
      _refuse('${refusal.forAgent}.');
    }
    emit(_fitted(state.copyWith(outbound: flight)));
  }

  /// Puts the traveller on flight [number] home to Warsaw on [date], one
  /// that find_flights gives.
  void setHomeboundFlight(String number, DateTime date) {
    final flight = _findFlight(number, date);
    if (_homeboundRefusal(flight, state) case final refusal?) {
      _refuse('${refusal.forAgent}.');
    }
    emit(_fitted(state.copyWith(homebound: flight)));
  }

  /// Finds the hotels in [city], with their price a night, the minutes on
  /// foot to the meetings and why the trip or the policy rules one out.
  List<HotelOption> findHotels(String city) => [
    for (final hotel in hotels.inCity(city))
      HotelOption(
        id: hotel.id.value,
        name: hotel.name,
        nightly: hotel.nightly.toInt(),
        walkMinutes: hotel.walkDuration.inMinutes,
        unavailable: _hotelRefusal(hotel)?.forAgent,
      ),
  ];

  /// Books the traveller into the hotel [hotelId], one that find_hotels
  /// gives, from the day they land to the day they fly home.
  void setHotel(String hotelId) {
    final id = HotelId.tryParse(hotelId);
    if (id == null) _refuse('A hotel id must not be empty.');
    final hotel = hotels.find(id);
    if (hotel == null) {
      _refuse('There is no hotel $hotelId.');
    }
    if (_hotelRefusal(hotel) case final refusal?) {
      _refuse('${refusal.forAgent}.');
    }
    if (state.nights == null) {
      _refuse(
        'Set both flights first: the stay runs from landing to the flight '
        'home.',
      );
    }
    if (state.nights case final nights? when nights <= 0) {
      _refuse('A trip that returns on the same day needs no hotel.');
    }
    emit(state.copyWith(hotel: hotel));
  }

  List<PlanPart> get missing => [
    if (form.city.fieldValue == null) .city,
    ...state.missingPicks,
  ];

  bool get ready => missing.isEmpty && form.value.canSubmit && !state.booking;

  Future<void> book() async {
    _synchronizeInvitation();
    if (!ready) return;

    final plan = _fitted(state);
    final city = form.city.fieldValue;
    _requireInvitationCity(city);
    final purpose = _purpose;
    final PlanTripState(:outbound, :homebound) = plan;
    if (city == null ||
        outbound == null ||
        homebound == null ||
        plan.missingPicks.isNotEmpty) {
      return;
    }

    final id = invitation?.tripId ?? trips.newId(city);
    if (!trips.reserveBooking(id)) {
      _synchronizeInvitation();
      return;
    }
    emit(state.copyWith(booking: true));
    form.markReadOnly();
    try {
      _log.info('Booking a trip to $city');
      if (!await form.validate()) return;
      // Waypoint's showcase books nothing for real.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      trips.add(
        Trip(
          id: id,
          city: city,
          purpose: purpose,
          booked: Itinerary(
            outbound: outbound,
            homebound: homebound,
            hotel: switch ((plan.hotel, plan.nights)) {
              (final hotel?, final nights?) when nights > 0 =>
                HotelStay.atNightlyRate(
                  name: hotel.name,
                  address: hotel.address,
                  checkIn: _checkIn(outbound.arrives),
                  nights: NightCount(nights),
                  nightlyRate: hotel.nightly,
                  confirmation: BookingReference(
                    'WP-H${hotel.nightly.toInt()}${outbound.departs.day}',
                  ),
                ),
              _ => null,
            },
            meetings: plan.meetings,
          ),
        ),
      );
      _log.info('Booked the trip $id');
      _showBooked(id);
    } finally {
      trips.releaseBooking(id);
      if (!isClosed && _notifiedBookedTrip == null) {
        emit(state.copyWith(booking: false));
        form.unmarkReadOnly();
      }
    }
  }

  void unmark(PlanTripInput input) =>
      emit(state.copyWith(marked: {...state.marked}..remove(input)));

  void _mark(PlanTripInput input) =>
      emit(state.copyWith(marked: {...state.marked, input}));

  String? get _purpose => switch (form.purpose.fieldValue.trim()) {
    '' => null,
    final purpose => purpose,
  };

  void _refit() {
    if (!isClosed) emit(_fitted(state));
  }

  PlanTripState _fitted(PlanTripState plan) {
    final fitted = plan.copyWith(
      outbound: switch (plan.outbound) {
        final flight? when _outboundRefusal(flight, plan) == null => flight,
        _ => null,
      },
      homebound: switch (plan.homebound) {
        final flight? when _homeboundRefusal(flight, plan) == null => flight,
        _ => null,
      },
    );
    return fitted.copyWith(
      hotel: switch ((fitted.hotel, fitted.nights)) {
        (final hotel?, final nights?)
            when nights > 0 && _hotelRefusal(hotel) == null =>
          hotel,
        _ => null,
      },
    );
  }

  PlanRefusal? _flightRefusal(Flight flight, PlanTripState plan) =>
      flight.destination == _home
      ? _homeboundRefusal(flight, plan)
      : _outboundRefusal(flight, plan);

  PlanRefusal? _outboundRefusal(Flight flight, PlanTripState plan) {
    final airport = tripAirports[form.city.fieldValue];
    if (airport == null) return const CityNotSet();
    if (flight.origin != _home || flight.destination != airport) {
      return WrongRoute(flight, origin: _home, destination: airport);
    }
    return BreaksPlanPolicy.of(Policy.checkOutbound(flight, plan.meetings));
  }

  PlanRefusal? _homeboundRefusal(Flight flight, PlanTripState plan) {
    final airport = tripAirports[form.city.fieldValue];
    if (airport == null) return const CityNotSet();
    if (flight.origin != airport || flight.destination != _home) {
      return WrongRoute(flight, origin: airport, destination: _home);
    }
    return BreaksPlanPolicy.of(Policy.checkHomebound(flight, plan.meetings));
  }

  PlanRefusal? _hotelRefusal(Hotel hotel) {
    final city = form.city.fieldValue;
    if (city == null) return const CityNotSet();
    if (hotel.city != city) return HotelNotInCity(hotel, city);
    return BreaksPlanPolicy.of(Policy.checkNightly(hotel.nightly));
  }

  void _requireInvitationCity(String? city) {
    if (invitation?.news case TripInvitation(city: final invitedCity)
        when city != null && city != invitedCity) {
      _refuse(
        'This invitation is for $invitedCity. Keep its city when planning the trip.',
      );
    }
  }

  Flight _findFlight(String number, DateTime date) {
    final flightNumber = FlightNumber.tryParse(number);
    if (flightNumber == null) _refuse('Invalid flight number: $number.');
    final flight = flights.find(flightNumber, date);
    if (flight == null) _refuse('There is no flight $number.');
    return flight;
  }

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

/// Check-in from 15:00, or an hour after landing when the flight lands
/// later.
DateTime _checkIn(DateTime lands) {
  final afternoon = DateTime(lands.year, lands.month, lands.day, 15);
  final arrival = lands.add(const Duration(hours: 1));
  return arrival.isAfter(afternoon) ? arrival : afternoon;
}
