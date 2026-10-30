import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/common/tandem/form_changes.dart';
import 'package:waypoint/features/plan_trip/plan_trip_form_controller.dart';
import 'package:waypoint/features/plan_trip/plan_trip_summary.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'plan_trip_cubit.g.dart';

final _log = Logger('PlanTrip');

/// Where Waypoint flies from.
const _home = 'WAW';

/// The new trip that an invitation or the traveller's words fill in. The
/// traveller books it with their own tap, so nothing here needs approval.
/// The company policy holds for the agent and the traveller alike.
@TandemAgent()
class PlanTripCubit({
  required final TripsCubit trips,
  required final FlightSearch flights,
  required final HotelSearch hotels,

  /// The invitation in the inbox that the trip is planned from, if any.
  final ForwardedEmail? invitation,
  @override required final PlanTripFormController form,
}) extends Cubit<PlanTripState>
    with
        _$PlanTripCubit,
        BlocPresentationMixin<PlanTripState, PlanTripPresentationEvent>,
        FormChanges<PlanTripState> {
  this : super(const PlanTripState()) {
    // Whoever changes the city, what no longer fits goes.
    form.addRelation(form.city, (city) => city, (_) => _refit());
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
  String get policy => Policy.forAgent;

  /// Sets the city of the trip: Berlin, Copenhagen or Vienna.
  void setCity(String city) {
    final known = form.city.options
        .where((name) => name.toLowerCase() == city.trim().toLowerCase())
        .firstOrNull;
    if (known == null) {
      _refuse('Waypoint flies only to Berlin, Copenhagen and Vienna.');
    }
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
      id: 'meeting-${state.meetings.length + 1}',
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
        unavailable: _flightRefusal(flight, state)?.forAgent,
      ),
  ];

  /// Puts the traveller on flight [number] from Warsaw on [date], one that
  /// find_flights gives.
  void setOutboundFlight(String number, DateTime date) {
    final flight = flights.find(number, date);
    if (flight == null) {
      _refuse('There is no flight $number.');
    }
    if (_outboundRefusal(flight, state) case final refusal?) {
      _refuse('${refusal.forAgent}.');
    }
    emit(state.copyWith(outbound: flight));
  }

  /// Puts the traveller on flight [number] home to Warsaw on [date], one
  /// that find_flights gives.
  void setHomeboundFlight(String number, DateTime date) {
    final flight = flights.find(number, date);
    if (flight == null) {
      _refuse('There is no flight $number.');
    }
    if (_homeboundRefusal(flight, state) case final refusal?) {
      _refuse('${refusal.forAgent}.');
    }
    emit(state.copyWith(homebound: flight));
  }

  /// Finds the hotels in [city], with their price a night, the minutes on
  /// foot to the meetings and why the trip or the policy rules one out.
  List<HotelOption> findHotels(String city) => [
    for (final hotel in hotels.inCity(city))
      HotelOption(
        id: hotel.id,
        name: hotel.name,
        nightly: hotel.nightly,
        walkMinutes: hotel.walkMinutes,
        unavailable: _hotelRefusal(hotel)?.forAgent,
      ),
  ];

  /// Books the traveller into the hotel [hotelId], one that find_hotels
  /// gives, from the day they land to the day they fly home.
  void setHotel(String hotelId) {
    final hotel = hotels.find(hotelId);
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
    emit(state.copyWith(hotel: hotel));
  }

  /// What is still missing before the trip can be booked.
  List<PlanPart> get missing => [
    if (form.city.fieldValue == null) .city,
    ...state.missingPicks,
  ];

  /// Whether the traveller can book the trip: nothing missing, nothing
  /// wrong, and not being booked already.
  bool get ready => missing.isEmpty && form.value.canSubmit && !state.booking;

  /// Books the trip as planned and keeps it with the traveller's trips,
  /// unless something is missing or does not fit.
  Future<void> book() async {
    if (!ready) return;

    final plan = _fitted(state);
    final city = form.city.fieldValue;
    final purpose = _purpose;
    final PlanTripState(:outbound, :homebound) = plan;
    if (city == null ||
        outbound == null ||
        homebound == null ||
        plan.missingPicks.isNotEmpty) {
      return;
    }

    _log.info('Booking a trip to $city');
    emit(state.copyWith(booking: true));
    form.markReadOnly();
    if (!await form.validate()) {
      if (isClosed) return;
      emit(state.copyWith(booking: false));
      form.unmarkReadOnly();
      return;
    }
    // Waypoint's showcase books nothing for real.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final id = switch (invitation?.tripId) {
      final tripId? when trips.tripOrNull(tripId) == null => tripId,
      _ => trips.newId(city),
    };
    trips.add(
      Trip(
        id: id,
        city: city,
        purpose: purpose,
        booked: Itinerary(
          outbound: outbound,
          homebound: homebound,
          hotel: switch ((plan.hotel, plan.nights)) {
            (final hotel?, final nights?) => HotelStay(
              name: hotel.name,
              address: hotel.address,
              checkIn: _checkIn(outbound.arrives),
              nights: nights,
              nightly: hotel.nightly,
              confirmation: 'WP-H${hotel.nightly}${outbound.departs.day}',
            ),
            _ => null,
          },
          meetings: plan.meetings,
        ),
      ),
    );
    _log.info('Booked the trip $id');
    if (!isClosed) {
      emitPresentation(PlanTripPresentationEventBooked(id));
    }
  }

  /// The traveller changed [input] by hand.
  void unmark(PlanTripInput input) =>
      emit(state.copyWith(marked: {...state.marked}..remove(input)));

  void _mark(PlanTripInput input) =>
      emit(state.copyWith(marked: {...state.marked, input}));

  /// What the trip is for, or null when it is blank.
  String? get _purpose => switch (form.purpose.fieldValue.trim()) {
    '' => null,
    final purpose => purpose,
  };

  void _refit() {
    if (!isClosed) emit(_fitted(state));
  }

  /// [plan] without the flights and the hotel that the city, its meetings
  /// and the policy do not allow.
  PlanTripState _fitted(PlanTripState plan) => plan.copyWith(
    outbound: switch (plan.outbound) {
      final flight? when _outboundRefusal(flight, plan) == null => flight,
      _ => null,
    },
    homebound: switch (plan.homebound) {
      final flight? when _homeboundRefusal(flight, plan) == null => flight,
      _ => null,
    },
    hotel: switch (plan.hotel) {
      final hotel? when _hotelRefusal(hotel) == null => hotel,
      _ => null,
    },
  );

  PlanRefusal? _flightRefusal(Flight flight, PlanTripState plan) =>
      flight.to == _home
      ? _homeboundRefusal(flight, plan)
      : _outboundRefusal(flight, plan);

  PlanRefusal? _outboundRefusal(Flight flight, PlanTripState plan) {
    final airport = tripAirports[form.city.fieldValue];
    if (airport == null) return const CityNotSet();
    if (flight.from != _home || flight.to != airport) {
      return WrongRoute(flight, from: _home, to: airport);
    }
    return BreaksPlanPolicy.of(Policy.checkOutbound(flight, plan.meetings));
  }

  PlanRefusal? _homeboundRefusal(Flight flight, PlanTripState plan) {
    final airport = tripAirports[form.city.fieldValue];
    if (airport == null) return const CityNotSet();
    if (flight.from != airport || flight.to != _home) {
      return WrongRoute(flight, from: airport, to: _home);
    }
    return BreaksPlanPolicy.of(Policy.checkHomebound(flight, plan.meetings));
  }

  PlanRefusal? _hotelRefusal(Hotel hotel) {
    final city = form.city.fieldValue;
    if (city == null) return const CityNotSet();
    if (hotel.city != city) return HotelNotInCity(hotel, city);
    return BreaksPlanPolicy.of(Policy.checkNightly(hotel.nightly));
  }

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

/// What the agent picks of a trip as it is being planned, before it is
/// booked. The city and the purpose are the form's.
@CopyWith()
final class const PlanTripState({
  final List<Meeting> meetings = const [],
  final Flight? outbound,
  final Flight? homebound,
  final Hotel? hotel,

  /// Whether the trip is being booked as it is. Nothing changes it then.
  final bool booking = false,

  /// What the agent filled in and the traveller has not changed.
  final Set<PlanTripInput> marked = const {},
}) with Equatable {
  @override
  List<Object?> get props => [
    meetings,
    outbound,
    homebound,
    hotel,
    booking,
    marked,
  ];

  /// The nights between landing and flying home, once both flights are set.
  int? get nights => switch ((outbound, homebound)) {
    (final out?, final home?) => dateOnly(
      home.departs,
    ).difference(dateOnly(out.arrives)).inDays,
    _ => null,
  };

  /// What the trip costs: both fares and every night at the hotel.
  int get total =>
      (outbound?.fare ?? 0) +
      (homebound?.fare ?? 0) +
      (hotel?.nightly ?? 0) * (nights ?? 0);

  /// What the agent still has to pick before the trip can be booked: the
  /// meetings, both flights and the hotel. The city is the form's.
  List<PlanPart> get missingPicks => [
    if (meetings.isEmpty) .meetings,
    if (outbound == null) .outbound,
    if (homebound == null) .homebound,
    if (hotel == null && (nights ?? 1) > 0) .hotel,
  ];
}

/// What of the trip the traveller can set by hand.
enum PlanTripInput() {
  city,
  purpose,
}

/// A part of a trip that the plan can miss.
enum PlanPart(
  /// The part in English, for the agent.
  final String forAgent,
) {
  city('the city'),
  meetings('the meetings'),
  outbound('the flight there'),
  homebound('the flight home'),
  hotel('the hotel'),
}

sealed class const PlanTripPresentationEvent();

/// The trip is booked as the trip [tripId].
final class const PlanTripPresentationEventBooked(final String tripId)
    extends PlanTripPresentationEvent;

/// Why the plan cannot take a flight or a hotel.
sealed class const PlanRefusal() {
  /// The refusal in English, for the agent.
  String get forAgent;
}

final class const CityNotSet() extends PlanRefusal {
  @override
  String get forAgent => 'Set the city first';
}

/// [flight] does not fly the trip's way, from [from] to [to].
final class const WrongRoute(
  final Flight flight, {
  required final String from,
  required final String to,
}) extends PlanRefusal {
  @override
  String get forAgent =>
      'Flight ${flight.number} does not fly from $from to $to';
}

final class const HotelNotInCity(final Hotel hotel, final String city)
    extends PlanRefusal {
  @override
  String get forAgent => '${hotel.name} is not in $city';
}

final class const BreaksPlanPolicy(final PolicyBreach breach)
    extends PlanRefusal {
  static BreaksPlanPolicy? of(PolicyBreach? breach) => switch (breach) {
    final breach? => BreaksPlanPolicy(breach),
    null => null,
  };

  @override
  String get forAgent => breach.forAgent;
}

/// Check-in from 15:00, or an hour after landing when the flight lands
/// later.
DateTime _checkIn(DateTime lands) {
  final afternoon = DateTime(lands.year, lands.month, lands.day, 15);
  final arrival = lands.add(const Duration(hours: 1));
  return arrival.isAfter(afternoon) ? arrival : afternoon;
}

/// A hotel as find_hotels gives it to the agent.
final class const HotelOption({
  required final String id,
  required final String name,
  required final int nightly,
  required final int walkMinutes,

  /// Why the traveller cannot take it, or null when they can.
  final String? unavailable,
});
