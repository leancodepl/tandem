import 'dart:async';

import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint/common/tandem/flight_option.dart';
import 'package:waypoint/features/trip/booking_changes.dart';
import 'package:waypoint/features/trip/trip_booking_result.dart';
import 'package:waypoint/features/trip/trip_presentation_event.dart';
import 'package:waypoint/features/trip/trip_state.dart';
import 'package:waypoint/features/trip/trip_summary.dart';
import 'package:waypoint/features/trip/trip_warning.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_state.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'trip_cubit.g.dart';

final _log = Logger('Trip');

@TandemAgent()
class TripCubit({
  /// The trip as booked when the screen opened.
  required final Trip info,

  /// Where a booking is kept, also once the screen is closed.
  required final TripsCubit trips,
  required final FlightSearch flights,
  required final Traveller traveller,
}) extends Cubit<TripState>
    with _$TripCubit, BlocPresentationMixin<TripState, TripPresentationEvent> {
  this : super(_initialState(info, trips)) {
    _bookings = trips.stream.listen((_) => _adoptConfirmed(trips.state));
  }

  late final StreamSubscription<TripsState> _bookings;

  static TripState _initialState(Trip info, TripsCubit trips) {
    final booked = trips.tripOrNull(info.id)?.booked ?? info.booked;
    return TripState(
      current: booked,
      booked: booked,
      booking: trips.state.pendingBookings.contains(info.id),
    );
  }

  void _adoptConfirmed(TripsState shared) {
    if (isClosed) return;
    final latest = shared.trips
        .where((trip) => trip.id == info.id)
        .firstOrNull
        ?.booked;
    if (latest == null) return;
    emit(
      state.withConfirmed(
        latest,
        booking: shared.pendingBookings.contains(info.id),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _bookings.cancel();
    await super.close();
  }

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(trip),
    .calls(findFlights),
    .calls(moveMeeting),
    .calls(setHomeboundFlight),
    if (itinerary.hotel?.nightlyRate != null) .calls(setHotelNights),
    if (canBookChanges) .callsWithApproval(bookChanges),
  ];

  @override
  Stream<Object?> get changes => stream;

  Itinerary get itinerary => state.current;

  /// The trip as the traveller sees it on the screen, with what is not
  /// booked yet.
  TripSummary get trip => TripSummary.of(
    info,
    itinerary,
    changes: bookingChanges,
    warnings: warnings,
    traveller: traveller,
    forwardedEmails: trips.news(info.id),
  );

  BookingChanges get bookingChanges =>
      BookingChanges.between(itinerary, state.booked);

  bool get canBookChanges =>
      bookingChanges.items.isNotEmpty &&
      !state.booking &&
      changesBreach == null;

  /// Why the changed bookings break the policy, or null when they can be
  /// booked. A booking that stays as it is does not count.
  PolicyBreach? get changesBreach {
    for (final change in bookingChanges.items) {
      final breach = switch (change) {
        HotelNightsChange(:final hotel) => switch (hotel.nightlyRate) {
          final rate? => Policy.checkNightly(rate),
          null => null,
        },
        FlightHomeChange(:final flight) => _homeboundBreach(flight),
      };
      if (breach != null) return breach;
    }
    return null;
  }

  List<TripWarning> get warnings {
    final hotel = itinerary.hotel;
    final home = calendarDay(itinerary.homebound.departs);
    final out = calendarDay(itinerary.outbound.arrives);
    final nights = calendarDaysBetween(out, home);
    return [
      if (hotel != null && nights > 0) ...[
        if (calendarDaysBetween(out, hotel.checkIn) > 0) NoHotelForNight(out),
        if (calendarDaysBetween(hotel.checkOut, home) > 0)
          NoHotelForNight(
            calendarDaysBetween(hotel.checkOut, out) > 0
                ? out
                : calendarDay(hotel.checkOut),
          ),
      ],
      if (hotel == null && nights > 0) NoHotelBooked(nights),
      if (_homeboundBreach(itinerary.homebound) case final breach?)
        BreaksPolicy(breach),
    ];
  }

  List<(Flight, PolicyBreach?)> get homeboundOptions => [
    for (final flight in flights.on(
      itinerary.homebound.origin,
      itinerary.homebound.destination,
      itinerary.homebound.departs,
    ))
      if (flight.departs.isAfter(itinerary.outbound.arrives))
        (flight, _homeboundBreach(flight)),
  ];

  // `origin`, not `from`: ag-ui-adk names the parameters in Python.
  /// Finds the flights from [origin] to [destination] on [date], with their
  /// fares in euros. Airports are IATA codes: WAW for Warsaw, BER for Berlin.
  List<FlightOption> findFlights(
    String origin,
    String destination,
    DateTime date,
  ) {
    final originCode = AirportCode.tryParse(origin);
    final destinationCode = AirportCode.tryParse(destination);
    if (originCode == null || destinationCode == null) {
      _refuse('Use three-letter airport codes, such as BER and WAW.');
    }
    return [
      for (final flight in flights.on(originCode, destinationCode, date))
        FlightOption(
          number: flight.number.value,
          departs: forAgent(flight.departs),
          arrives: forAgent(flight.arrives),
          fare: flight.fare.toInt(),
          unavailable: destinationCode == itinerary.homebound.destination
              ? _homeboundFlightRefusal(flight)
              : null,
        ),
    ];
  }

  /// Moves the meeting [meetingId] to start at [start], keeping its length.
  /// Meetings are in the traveller's calendar, so moving one books nothing.
  void moveMeeting(String meetingId, DateTime start) {
    final id = MeetingId.tryParse(meetingId);
    if (id == null) _refuse('A meeting id must not be empty.');
    final meeting = itinerary.meeting(id);
    if (meeting == null) {
      _refuse('There is no meeting $meetingId on this trip.');
    }
    trips.moveMeeting(info.id, meeting.movedTo(start));
    _adoptConfirmed(trips.state);
  }

  /// Puts the traveller on flight [number] home on [date], one that
  /// find_flights gives. Nothing is booked until book_changes.
  void setHomeboundFlight(String number, DateTime date) {
    final flightNumber = FlightNumber.tryParse(number);
    if (flightNumber == null) _refuse('Invalid flight number: $number.');
    final flight = flights.find(flightNumber, date);
    if (flight == null) {
      _refuse('There is no flight $number home.');
    }
    if (changeHomeboundFlight(flight) case final breach?) {
      _refuse('${breach.forAgent}.');
    }
  }

  PolicyBreach? changeHomeboundFlight(Flight flight) {
    final booked = info.booked.homebound;
    if (flight.origin != booked.origin ||
        flight.destination != booked.destination) {
      _refuse(
        'The flight home must fly from ${booked.origin} to ${booked.destination}.',
      );
    }
    if (!flight.departs.isAfter(itinerary.outbound.arrives)) {
      _refuse('The flight home must leave after the flight there lands.');
    }
    if (_homeboundBreach(flight) case final breach?) return breach;

    emit(_with(itinerary.copyWith(homebound: flight)));
    return null;
  }

  /// Sets how many nights the traveller stays at the hotel, counted from the
  /// check-in. Nothing is booked until book_changes.
  void setHotelNights(int nights) {
    final hotel = itinerary.hotel;
    if (hotel == null) {
      _refuse('This trip has no hotel yet.');
    }
    if (nights < 1 || nights > 14) {
      _refuse('A stay is 1 to 14 nights.');
    }
    if (nights == hotel.nights.value) return;
    if (hotel.nightlyRate == null) {
      _refuse(
        'This hotel has a confirmed total, but no nightly quote for changing the stay.',
      );
    }
    emit(
      _with(itinerary.copyWith(hotel: hotel.withNights(NightCount(nights)))),
    );
  }

  /// Adds [hotel] to the trip as booked: the traveller booked it themselves.
  void addHotel(HotelStay hotel) {
    trips.confirmHotel(info.id, hotel);
    _adoptConfirmed(trips.state);
  }

  /// Books every change exactly as it is on the screen and charges its cost
  /// to the company card. Returns what was booked, to tell the traveller.
  Future<Booked> bookChanges() async {
    _adoptConfirmed(trips.state);
    if (state.booking) _refuse('The changes are already being booked.');
    final changes = bookingChanges;
    if (changes.items.isEmpty) _refuse('There are no booking changes.');
    if (changesBreach case final breach?) _refuse('${breach.forAgent}.');
    final booking = itinerary;
    final previouslyBooked = state.booked;
    if (!trips.reserveBooking(info.id)) {
      _refuse('The changes are already being booked.');
    }
    _adoptConfirmed(trips.state);
    try {
      _log.info('Booking ${changes.items.length} changes of trip ${info.id}');
      // Waypoint's showcase books nothing for real.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final confirmation = BookingReference(
        'WP-${48213 + booking.homebound.departs.day}',
      );
      final completed = trips.tryCompleteBooking(
        info.id,
        previouslyBooked: previouslyBooked,
        requested: booking,
      );
      if (!completed) {
        _refuse(
          'The hotel booking changed while these changes were being booked. '
          'Review the current trip before booking again.',
        );
      }
      _adoptConfirmed(trips.state);
      _log.info('Booked the changes of trip ${info.id} as $confirmation');
      if (!isClosed) {
        emitPresentation(TripPresentationEventChangesBooked(confirmation));
      }
      return Booked(
        confirmation: confirmation.value,
        changes: [
          for (final ChangeSummary(:what, :now) in changes.items.map(
            ChangeSummary.of,
          ))
            '$what: $now',
        ],
        charged: changes.totalCost.toInt(),
      );
    } finally {
      trips.releaseBooking(info.id);
      _adoptConfirmed(trips.state);
    }
  }

  String? _homeboundFlightRefusal(Flight flight) {
    if (flight.departs.isAfter(itinerary.outbound.arrives)) {
      return _homeboundBreach(flight)?.forAgent;
    }
    return 'The flight home must leave after the flight there lands.';
  }

  PolicyBreach? _homeboundBreach(Flight flight) =>
      Policy.checkHomebound(flight, itinerary.meetings);

  TripState _with(Itinerary itinerary) => TripState(
    current: itinerary,
    booked: state.booked,
    booking: state.booking,
  );

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}
