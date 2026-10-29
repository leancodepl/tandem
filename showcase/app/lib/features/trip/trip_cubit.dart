import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/features/trip/trip_summary.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'trip_cubit.g.dart';

final _log = Logger('Trip');

/// What a changed flight costs on top of the fare difference.
const changeFee = 40;

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
  this : super(TripState(current: info.booked, booked: info.booked));

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(trip),
    .calls(findFlights),
    .calls(moveMeeting),
    .calls(setHomeboundFlight),
    .calls(setHotelNights),
    if (bookingChanges.isNotEmpty && !state.booking && changesBreach == null)
      .callsWithApproval(bookChanges),
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
  );

  /// The bookings that differ from what is booked, in the order the screen
  /// lists them.
  List<BookingChange> get bookingChanges {
    final now = itinerary;
    final was = state.booked;
    return [
      if ((now.hotel, was.hotel) case (final hotel?, final booked?)
          when hotel.nights != booked.nights)
        HotelNightsChange(hotel, was: booked),
      if (!now.homebound.isSameAs(was.homebound))
        FlightHomeChange(now.homebound, was: was.homebound),
    ];
  }

  /// Why the changed bookings break the policy, or null when they can be
  /// booked. A booking that stays as it is does not count.
  PolicyBreach? get changesBreach =>
      switch (bookingChanges.whereType<FlightHomeChange>().firstOrNull) {
        final change? => _homeboundBreach(change.flight),
        null => null,
      };

  int get changesCost =>
      bookingChanges.fold(0, (sum, change) => sum + change.cost);

  /// What does not fit together on the screen now.
  List<TripWarning> get warnings {
    final hotel = itinerary.hotel;
    final home = dateOnly(itinerary.homebound.departs);
    final out = dateOnly(itinerary.outbound.departs);
    return [
      if (hotel != null && dateOnly(hotel.checkOut).isBefore(home))
        NoHotelForNight(dateOnly(hotel.checkOut)),
      if (hotel == null && home.isAfter(out))
        NoHotelBooked(home.difference(out).inDays),
      if (_homeboundBreach(itinerary.homebound) case final breach?)
        BreaksPolicy(breach),
    ];
  }

  /// The flights home on the homebound day, for the screen's picker.
  List<(Flight, PolicyBreach?)> get homeboundOptions => [
    for (final flight in flights.on(
      itinerary.homebound.from,
      itinerary.homebound.to,
      itinerary.homebound.departs,
    ))
      (flight, _homeboundBreach(flight)),
  ];

  // `origin`, not `from`: ag-ui-adk names the parameters in Python.
  /// Finds the flights from [origin] to [destination] on [date], with their
  /// fares in euros. Airports are IATA codes: WAW for Warsaw, BER for Berlin.
  List<FlightOption> findFlights(
    String origin,
    String destination,
    DateTime date,
  ) => [
    for (final flight in flights.on(
      origin.toUpperCase(),
      destination.toUpperCase(),
      date,
    ))
      FlightOption(
        number: flight.number,
        departs: forAgent(flight.departs),
        arrives: forAgent(flight.arrives),
        fare: flight.fare,
        unavailable: destination.toUpperCase() == itinerary.homebound.to
            ? _homeboundBreach(flight)?.forAgent
            : null,
      ),
  ];

  /// Moves the meeting [meetingId] to start at [start], keeping its length.
  /// Meetings are in the traveller's calendar, so moving one books nothing.
  void moveMeeting(String meetingId, DateTime start) {
    final meeting = itinerary.meeting(meetingId);
    if (meeting == null) {
      _refuse('There is no meeting $meetingId on this trip.');
    }
    emit(
      _with(
        itinerary.copyWith(
          meetings: [
            for (final other in itinerary.meetings)
              if (other.id == meetingId) other.movedTo(start) else other,
          ],
        ),
      ),
    );
  }

  /// Puts the traveller on flight [number] home on [date], one that
  /// find_flights gives. Nothing is booked until book_changes.
  void setHomeboundFlight(String number, DateTime date) {
    final flight = flights.find(number, date);
    if (flight == null || flight.from != itinerary.homebound.from) {
      _refuse('There is no flight $number home.');
    }
    if (changeHomeboundFlight(flight) case final breach?) {
      _refuse('${breach.forAgent}.');
    }
  }

  /// Puts the traveller on [flight] home, unless the policy rules it out.
  PolicyBreach? changeHomeboundFlight(Flight flight) {
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
    emit(_with(itinerary.copyWith(hotel: hotel.copyWith(nights: nights))));
  }

  /// Adds [hotel] to the trip as booked: the traveller booked it themselves.
  void addHotel(HotelStay hotel) {
    final booked = state.booked.copyWith(hotel: hotel);
    trips.book(info.id, booked);
    emit(
      TripState(
        current: itinerary.copyWith(hotel: hotel),
        booked: booked,
      ),
    );
  }

  /// Books every change exactly as it is on the screen and charges its cost
  /// to the company card. Returns what was booked, to tell the traveller.
  Future<Booked> bookChanges() async {
    if (changesBreach case final breach?) {
      _refuse('${breach.forAgent}.');
    }
    final booking = itinerary;
    final changes = bookingChanges;
    _log.info('Booking ${changes.length} changes of trip ${info.id}');
    emit(TripState(current: booking, booked: state.booked, booking: true));
    // Waypoint's showcase books nothing for real.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final confirmation = 'WP-${48213 + booking.homebound.departs.day}';
    trips.book(info.id, booking);
    _log.info('Booked the changes of trip ${info.id} as $confirmation');
    if (!isClosed) {
      emit(TripState(current: itinerary, booked: booking));
      emitPresentation(TripPresentationEventChangesBooked(confirmation));
    }
    return Booked(
      confirmation: confirmation,
      changes: [
        for (final ChangeSummary(:what, :now) in changes.map(ChangeSummary.of))
          '$what: $now',
      ],
      charged: changes.fold(0, (sum, change) => sum + change.cost),
    );
  }

  PolicyBreach? _homeboundBreach(Flight flight) =>
      Policy.checkHomebound(flight, itinerary.meetings);

  TripState _with(Itinerary itinerary) =>
      TripState(current: itinerary, booked: state.booked);

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

final class const TripState({
  required final Itinerary current,
  required final Itinerary booked,
  final bool booking = false,
}) with Equatable {
  @override
  List<Object?> get props => [current, booked, booking];
}

sealed class const TripPresentationEvent();

/// The changes are booked under [confirmation].
final class const TripPresentationEventChangesBooked(final String confirmation)
    extends TripPresentationEvent;

/// One booking that differs from what is booked.
sealed class const BookingChange() with Equatable {
  /// The item of the trip that changes.
  String get id;

  /// What the change costs on top of the booking, in euros.
  int get cost;
}

/// The stay at [hotel] has another number of nights than [was].
final class const HotelNightsChange(
  final HotelStay hotel, {
  required final HotelStay was,
}) extends BookingChange {
  @override
  List<Object?> get props => [hotel, was];

  @override
  String get id => 'hotel';

  @override
  int get cost => (hotel.nights - was.nights) * hotel.nightly;
}

/// The traveller flies home on [flight] instead of [was].
final class const FlightHomeChange(
  final Flight flight, {
  required final Flight was,
}) extends BookingChange {
  @override
  List<Object?> get props => [flight, was];

  @override
  String get id => 'homebound';

  @override
  int get cost => flight.fare - was.fare + changeFee;
}

/// What does not fit together on the trip.
sealed class const TripWarning() with Equatable;

/// The hotel stay ends on [night], before the flight home.
final class const NoHotelForNight(final DateTime night) extends TripWarning {
  @override
  List<Object?> get props => [night];
}

final class const NoHotelBooked(final int nights) extends TripWarning {
  @override
  List<Object?> get props => [nights];
}

final class const BreaksPolicy(final PolicyBreach breach) extends TripWarning {
  @override
  List<Object?> get props => [breach];
}

/// What book_changes booked.
final class const Booked({
  required final String confirmation,

  /// Each booking that changed, as the screen shows it now.
  required final List<String> changes,

  /// Charged to the company card, in euros.
  required final int charged,
});
