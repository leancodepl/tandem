import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
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
  required final Trip trip,
  required final ArrivalDay day,
  required final ArrivalArrangementsCubit arrangements,
}) extends Cubit<ArrivalState> with _$ArrivalCubit {
  this : super(arrangements.forTrip(trip.id)) {
    _arrangementsChanges = arrangements.stream
        .map((all) => all[trip.id] ?? const ArrivalState())
        .distinct()
        .listen(emit);
  }

  final Meeting meeting = _meetingOf(trip, day);
  late final StreamSubscription<ArrivalState> _arrangementsChanges;

  ArrivalState get _arranged => arrangements.forTrip(trip.id);

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(arrival),
    if (_canBookRide) .callsWithApproval(bookRide),
    if (!_arranged.hostTold) .callsWithApproval(messageHost),
    if (trip.booked.hotel != null && !_arranged.earlyCheckIn)
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
      hostTold: _arranged.hostTold,
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
      roomReady: _arranged.earlyCheckIn ? day.roomReadyEarly : null,
    ),
    policy: Policy.ridesForAgent,
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
    if (_arranged.hostTold) _refuse('The host has already been told.');
    final arrives = switch (_arranged.ride) {
      RideBooking(:final rideId) => _arrives(
        day.rides.firstWhere((ride) => ride.id == rideId),
      ),
      null => lands.add(const Duration(hours: 1)),
    };
    final message =
        'Hi ${day.host.name.split(' ').first}, I land at '
        '${timeForAgent(lands)} and will be at the studio around '
        '${timeForAgent(arrives)}. See you at '
        '${timeForAgent(meeting.start)}! Ola';
    _log.info('Messaged the host of trip ${trip.id}');
    arrangements.markHostTold(trip.id);
    return message;
  }

  /// Asks the hotel to have the room ready early, for the bags. It costs
  /// nothing.
  void requestEarlyCheckIn() {
    if (trip.booked.hotel == null) {
      _refuse('There is no hotel booking for an early check-in.');
    }
    _log.info('Asked for an early check-in on trip ${trip.id}');
    arrangements.requestEarlyCheckIn(trip.id);
  }

  @override
  Future<void> close() async {
    await _arrangementsChanges.cancel();
    await super.close();
  }

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
