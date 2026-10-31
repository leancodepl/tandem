import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'arrival_cubit.g.dart';

final _log = Logger('Arrival');

/// From the gate to the taxi rank or the platform.
const _toRide = Duration(minutes: 10);

/// The traveller's arrival day. The agent draws it with Waypoint's widgets,
/// and the buttons of its view call these methods: those that charge the
/// company card or write in the traveller's name wait for approval.
@TandemAgent()
class ArrivalCubit({
  required final TripId tripId,
  required final TripsCubit trips,
  required final ArrivalDay day,
  required final ArrivalArrangementsCubit arrangements,
}) extends Cubit<ArrivalState> with _$ArrivalCubit {
  this
    : super(
        ArrivalState(
          trip: _tripOf(trips, tripId),
          arrangements: arrangements.forTrip(tripId),
        ),
      ) {
    _meetingOf(trip, day);
    _arrangementsChanges = arrangements.stream.listen((_) => _refresh());
    _tripChanges = trips.stream.listen((_) => _refresh());
  }

  late final StreamSubscription<Map<TripId, ArrivalArrangements>>
  _arrangementsChanges;
  late final StreamSubscription<TripsState> _tripChanges;

  Trip get trip => trips.tripOrNull(tripId) ?? state.trip;
  Meeting get meeting => _meetingOf(trip, day);
  ArrivalArrangements get _arranged => arrangements.forTrip(tripId);
  bool get _hostTold => _arranged.hostMessage == _messageToSend;

  DateTime? get _roomReady =>
      switch ((_arranged.earlyCheckIn, trip.booked.hotel)) {
        (EarlyCheckIn(:final confirmation, :final roomReady), final hotel?)
            when confirmation == hotel.confirmation &&
                calendarDaysBetween(roomReady, hotel.checkIn) == 0 =>
          roomReady,
        _ => null,
      };

  HotelStay? get _hotelForEarlyCheckIn => switch (trip.booked.hotel) {
    final hotel?
        when calendarDaysBetween(day.roomReadyEarly, hotel.checkIn) == 0 =>
      hotel,
    _ => null,
  };

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(arrival),
    if (_canBookRide) .callsWithApproval(bookRide),
    if (_arranged.pendingRide == null && !_hostTold)
      .callsWithApproval(messageHost),
    if (_hotelForEarlyCheckIn != null && _roomReady == null)
      .calls(requestEarlyCheckIn),
  ];

  @override
  Stream<Object?> get changes => stream;

  DateTime get lands => trip.booked.outbound.arrives;

  /// The arrival day as the traveller sees it: the first meeting, the ways
  /// there, the host and the hotel, with what is arranged already.
  ArrivalSummary get arrival => ArrivalSummary(
    landing:
        '${forAgent(lands)} at '
        '${trip.booked.outbound.destination}, flight ${trip.booked.outbound.number}',
    meeting: MeetingNext(
      title: meeting.title,
      place: meeting.place,
      start: meeting.start,
      host: day.host.name,
      hostTold: _hostTold,
    ),
    rides: [
      for (final ride in day.rides)
        RideSummary(
          id: ride.id.value,
          mode: ride.mode,
          minutes: ride.duration.inMinutes,
          fare: ride.fare.toInt(),
          arrives: _arrives(ride),
          booked: switch (_arranged.ride) {
            RideBooking(:final rideId, :final reference)
                when rideId == ride.id =>
              reference.value,
            _ => null,
          },
          overPolicy: _overPolicy(ride) != null,
        ),
    ],
    hotel: HotelNext(
      name: trip.booked.hotel?.name,
      checkIn: trip.booked.hotel?.checkIn,
      roomReady: _roomReady,
    ),
    policy: PolicyAgentText.rides,
  );

  /// Books the ride [rideId] from the airport and charges its fare to the
  /// company card. Returns the booking, to tell the traveller.
  Future<String> bookRide(String rideId) async {
    if (_arranged.ride != null) _refuse('A ride is already booked.');
    if (_arranged.pendingRide != null) _refuse('A ride is being booked.');
    final id = RideId.tryParse(rideId);
    final ride = day.rides.where((ride) => ride.id == id).firstOrNull;
    if (ride == null) {
      _refuse('There is no ride $rideId.');
    }
    if (_overPolicy(ride) case final breach?) {
      _refuse(breach.forAgent);
    }
    _log.info('Booking the ride $rideId of trip ${trip.id}');
    final booking = await arrangements.bookRide(trip.id, ride);
    _log.info('Booked the ride $rideId of trip ${trip.id}');
    return booking;
  }

  /// Texts the meeting's host, in the traveller's name, when the traveller
  /// lands and arrives. Returns the message as sent.
  String messageHost() {
    if (_arranged.pendingRide != null) {
      _refuse('Wait for the ride booking before messaging the host.');
    }
    if (_hostTold) _refuse('The host already has this arrival update.');
    final message = _messageToSend;
    _log.info('Messaged the host of trip $tripId');
    arrangements.recordHostMessage(tripId, message);
    return message.text;
  }

  SentHostMessage get _messageToSend {
    final arrives = switch (_arranged.ride) {
      RideBooking(:final rideId) => _arrives(
        day.rides.firstWhere((ride) => ride.id == rideId),
      ),
      null => lands.add(const Duration(hours: 1)),
    };
    return SentHostMessage(
      phone: day.host.phone,
      text:
          'Hi ${day.host.name.split(' ').first}, I land at '
          '${timeForAgent(lands)} on ${forAgent(lands, withTime: false)} and will be at the studio around '
          '${timeForAgent(arrives)} on ${forAgent(arrives, withTime: false)}. See you at '
          '${timeForAgent(meeting.start)} on ${forAgent(meeting.start, withTime: false)}! Ola',
    );
  }

  /// Asks the hotel to have the room ready early, for the bags. It costs
  /// nothing.
  void requestEarlyCheckIn() {
    final hotel = _hotelForEarlyCheckIn;
    if (hotel == null) {
      _refuse('Early check-in is not available for this hotel booking.');
    }
    _log.info('Asked for an early check-in on trip ${trip.id}');
    arrangements.confirmEarlyCheckIn(
      tripId,
      EarlyCheckIn(
        confirmation: hotel.confirmation,
        roomReady: day.roomReadyEarly,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _arrangementsChanges.cancel();
    await _tripChanges.cancel();
    await super.close();
  }

  void _refresh() => emit(ArrivalState(trip: trip, arrangements: _arranged));

  static Trip _tripOf(TripsCubit trips, TripId tripId) =>
      trips.tripOrNull(tripId) ??
      (throw ArgumentError.value(tripId, 'tripId', 'The trip does not exist.'));

  bool get _canBookRide =>
      _arranged.ride == null && _arranged.pendingRide == null;

  DateTime _arrives(Ride ride) => lands.add(_toRide).add(ride.duration);

  PolicyBreach? _overPolicy(Ride ride) => Policy.checkRide(
    ride.mode,
    trainArrives: switch (day.rides
        .where((it) => it.mode == .train)
        .firstOrNull) {
      final train? => _arrives(train),
      null => null,
    },
    meetingStarts: meeting.start,
  );

  static Meeting _meetingOf(Trip trip, ArrivalDay day) {
    if (trip.id != day.tripId) {
      throw ArgumentError('The arrival day belongs to another trip.');
    }
    final meeting = trip.booked.meeting(day.meetingId);
    if (meeting != null) return meeting;
    throw ArgumentError.value(
      day.meetingId,
      'meetingId',
      'The arrival meeting must be in the booked itinerary.',
    );
  }

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

final class const ArrivalState({
  required final Trip trip,
  required final ArrivalArrangements arrangements,
}) with Equatable {
  @override
  List<Object?> get props => [trip, arrangements];
}

final class const ArrivalSummary({
  required final String landing,
  required final MeetingNext meeting,
  required final List<RideSummary> rides,
  required final HotelNext hotel,

  /// The company's rule for rides.
  required final String policy,
});

final class const MeetingNext({
  required final String title,
  required final String place,
  required final DateTime start,
  required final String host,

  /// Whether the traveller texted the host when they arrive.
  required final bool hostTold,
});

final class const RideSummary({
  required final String id,
  required final RideMode mode,
  required final int minutes,

  /// In whole euros.
  required final int fare,
  required final DateTime arrives,

  /// The booking's reference once booked: the taxi's plate or the ticket's
  /// fare zone.
  final String? booked,

  /// Whether the company's rule for rides rules it out.
  required final bool overPolicy,
});

final class const HotelNext({
  /// Null without a hotel booked.
  final String? name,
  final DateTime? checkIn,

  /// When the room is ready, once the traveller asked for an early
  /// check-in.
  final DateTime? roomReady,
});
