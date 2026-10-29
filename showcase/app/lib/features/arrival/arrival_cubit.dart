import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'arrival_cubit.g.dart';

final _log = Logger('Arrival');

/// From the gate to the taxi rank or the platform.
const _toRide = Duration(minutes: 10);

/// The traveller's arrival day. The agent draws it with Waypoint's widgets,
/// and the buttons of its view call these methods: those that charge the
/// company card or write in the traveller's name wait for approval.
@TandemAgent()
class ArrivalCubit({required final Trip trip, required final ArrivalDay day})
    extends Cubit<ArrivalState>
    with _$ArrivalCubit {
  this : super(const ArrivalState());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(arrival),
    if (state.ride == null) .callsWithApproval(bookRide),
    if (!state.hostTold) .callsWithApproval(messageHost),
    if (!state.earlyCheckIn) .calls(requestEarlyCheckIn),
  ];

  @override
  Stream<Object?> get changes => stream;

  DateTime get lands => trip.booked.outbound.arrives;

  /// The arrival day as the traveller sees it: the first meeting, the ways
  /// there, the host and the hotel, with what is arranged already.
  ArrivalSummary get arrival => ArrivalSummary(
    landing:
        '${forAgent(lands)} at '
        '${trip.booked.outbound.to}, flight ${trip.booked.outbound.number}',
    meeting: MeetingNext(
      title: day.meeting,
      place: day.meetingPlace,
      start: day.meetingStart,
      host: day.host.name,
      hostTold: state.hostTold,
    ),
    rides: [
      for (final ride in day.rides)
        RideSummary(
          id: ride.id,
          mode: ride.mode,
          minutes: ride.minutes,
          fare: ride.fare,
          arrives: _arrives(ride),
          booked: switch (state.ride) {
            (final id, final reference) when id == ride.id => reference,
            _ => null,
          },
          overPolicy: _overPolicy(ride) != null,
        ),
    ],
    hotel: HotelNext(
      name: trip.booked.hotel?.name,
      checkIn: trip.booked.hotel?.checkIn,
      roomReady: state.earlyCheckIn ? day.roomReadyEarly : null,
    ),
    policy: Policy.ridesForAgent,
  );

  /// Books the ride [rideId] from the airport and charges its fare to the
  /// company card. Returns the booking, to tell the traveller.
  Future<String> bookRide(String rideId) async {
    final ride = day.rides.where((ride) => ride.id == rideId).firstOrNull;
    if (ride == null) {
      _refuse('There is no ride $rideId.');
    }
    if (_overPolicy(ride) case final breach?) {
      _refuse(breach.forAgent);
    }
    _log.info('Booking the ride $rideId of trip ${trip.id}');
    // Waypoint's showcase books nothing for real.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final (reference, booking) = switch (ride.mode) {
      .taxi => ('B-TX 482', 'Taxi B-TX 482, at the rank when you land'),
      .train => ('AB', 'S-Bahn ticket AB, valid for 2 hours'),
    };
    _log.info('Booked the ride $rideId of trip ${trip.id}');
    if (!isClosed) {
      emit(state.copyWith(ride: (ride.id, reference)));
    }
    return booking;
  }

  /// Texts the meeting's host, in the traveller's name, when the traveller
  /// lands and arrives. Returns the message as sent.
  String messageHost() {
    final arrives = switch (state.ride) {
      (final id, _) => _arrives(day.rides.firstWhere((ride) => ride.id == id)),
      null => lands.add(const Duration(hours: 1)),
    };
    final message =
        'Hi ${day.host.name.split(' ').first}, I land at '
        '${timeForAgent(lands)} and will be at the studio around '
        '${timeForAgent(arrives)}. See you at '
        '${timeForAgent(day.meetingStart)}! Ola';
    _log.info('Messaged the host of trip ${trip.id}');
    emit(state.copyWith(hostTold: true));
    return message;
  }

  /// Asks the hotel to have the room ready early, for the bags. It costs
  /// nothing.
  void requestEarlyCheckIn() {
    _log.info('Asked for an early check-in on trip ${trip.id}');
    emit(state.copyWith(earlyCheckIn: true));
  }

  DateTime _arrives(Ride ride) =>
      lands.add(_toRide).add(Duration(minutes: ride.minutes));

  PolicyBreach? _overPolicy(Ride ride) => Policy.checkRide(
    ride.mode,
    trainArrives: switch (day.rides
        .where((it) => it.mode == .train)
        .firstOrNull) {
      final train? => _arrives(train),
      null => null,
    },
    meetingStarts: day.meetingStart,
  );

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

/// What the traveller arranged for their arrival.
@CopyWith()
final class const ArrivalState({
  /// The booked ride's id and its booking's reference.
  final (String, String)? ride,
  final bool hostTold = false,
  final bool earlyCheckIn = false,
}) with Equatable {
  @override
  List<Object?> get props => [ride, hostTold, earlyCheckIn];
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
