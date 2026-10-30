// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'arrival_cubit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ArrivalStateCWProxy {
  ArrivalState ride((String, String)? ride);

  ArrivalState hostTold(bool hostTold);

  ArrivalState earlyCheckIn(bool earlyCheckIn);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ArrivalState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ArrivalState(...).copyWith(id: 12, name: "My name")
  /// ```
  ArrivalState call({(String, String)? ride, bool hostTold, bool earlyCheckIn});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfArrivalState.copyWith(...)` or call `instanceOfArrivalState.copyWith.fieldName(value)` for a single field.
class _$ArrivalStateCWProxyImpl implements _$ArrivalStateCWProxy {
  const _$ArrivalStateCWProxyImpl(this._value);

  final ArrivalState _value;

  @override
  ArrivalState ride((String, String)? ride) => call(ride: ride);

  @override
  ArrivalState hostTold(bool hostTold) => call(hostTold: hostTold);

  @override
  ArrivalState earlyCheckIn(bool earlyCheckIn) =>
      call(earlyCheckIn: earlyCheckIn);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ArrivalState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ArrivalState(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ArrivalState call({
    Object? ride = const $CopyWithPlaceholder(),
    Object? hostTold = const $CopyWithPlaceholder(),
    Object? earlyCheckIn = const $CopyWithPlaceholder(),
  }) {
    return ArrivalState(
      ride: ride == const $CopyWithPlaceholder()
          ? _value.ride
          // ignore: cast_nullable_to_non_nullable
          : ride as (String, String)?,
      hostTold: hostTold == const $CopyWithPlaceholder() || hostTold == null
          ? _value.hostTold
          // ignore: cast_nullable_to_non_nullable
          : hostTold as bool,
      earlyCheckIn:
          earlyCheckIn == const $CopyWithPlaceholder() || earlyCheckIn == null
          ? _value.earlyCheckIn
          // ignore: cast_nullable_to_non_nullable
          : earlyCheckIn as bool,
    );
  }
}

extension $ArrivalStateCopyWith on ArrivalState {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfArrivalState.copyWith(...)` or `instanceOfArrivalState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ArrivalStateCWProxy get copyWith => _$ArrivalStateCWProxyImpl(this);
}

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ArrivalCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ArrivalCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.arrival).as(
          'arrival',
          'The arrival day as the traveller sees it: the first meeting, the ways there, the host and the hotel, with what is arranged already.',
          .object(
            id: 'package:waypoint/features/arrival/arrival_cubit.dart#ArrivalSummary',
            fields: (field) => [
              field('landing', (value) => value.landing).as(.string),
              field('meeting', (value) => value.meeting).as(
                .object(
                  id: 'package:waypoint/features/arrival/arrival_cubit.dart#MeetingNext',
                  fields: (field) => [
                    field('title', (value) => value.title).as(.string),
                    field('place', (value) => value.place).as(.string),
                    field('start', (value) => value.start).as(.dateTime),
                    field('host', (value) => value.host).as(.string),
                    field(
                      'hostTold',
                      (value) => value.hostTold,
                      description: 'Whether the traveller texted the host when they arrive.',
                    ).as(.boolean),
                  ],
                  build: (values) => .new(
                    title: values('title'),
                    place: values('place'),
                    start: values('start'),
                    host: values('host'),
                    hostTold: values('hostTold'),
                  ),
                ),
              ),
              field('rides', (value) => value.rides).as(
                .list(
                  .object(
                    id: 'package:waypoint/features/arrival/arrival_cubit.dart#RideSummary',
                    fields: (field) => [
                      field('id', (value) => value.id).as(.string),
                      field('mode', (value) => value.mode).as(
                        .enumeration(
                          [.taxi, .train],
                          id: 'package:waypoint_travel/src/arrival.dart#RideMode',
                        ),
                      ),
                      field('minutes', (value) => value.minutes).as(.integer),
                      field(
                        'fare',
                        (value) => value.fare,
                        description: 'In whole euros.',
                      ).as(.integer),
                      field('arrives', (value) => value.arrives).as(.dateTime),
                      field(
                        'booked',
                        (value) => value.booked,
                        description: "The booking's reference once booked: the taxi's plate or the ticket's fare zone.",
                        required: false,
                      ).as(.nullable(.string)),
                      field(
                        'overPolicy',
                        (value) => value.overPolicy,
                        description: "Whether the company's rule for rides rules it out.",
                      ).as(.boolean),
                    ],
                    build: (values) => .new(
                      id: values('id'),
                      mode: values('mode'),
                      minutes: values('minutes'),
                      fare: values('fare'),
                      arrives: values('arrives'),
                      booked: values('booked'),
                      overPolicy: values('overPolicy'),
                    ),
                  ),
                ),
              ),
              field('hotel', (value) => value.hotel).as(
                .object(
                  id: 'package:waypoint/features/arrival/arrival_cubit.dart#HotelNext',
                  fields: (field) => [
                    field(
                      'name',
                      (value) => value.name,
                      description: 'Null without a hotel booked.',
                      required: false,
                    ).as(.nullable(.string)),
                    field(
                      'checkIn',
                      (value) => value.checkIn,
                      required: false,
                    ).as(.nullable(.dateTime)),
                    field(
                      'roomReady',
                      (value) => value.roomReady,
                      description: 'When the room is ready, once the traveller asked for an early check-in.',
                      required: false,
                    ).as(.nullable(.dateTime)),
                  ],
                  build: (values) => .new(
                    name: values('name'),
                    checkIn: values('checkIn'),
                    roomReady: values('roomReady'),
                  ),
                ),
              ),
              field(
                'policy',
                (value) => value.policy,
                description: "The company's rule for rides.",
              ).as(.string),
            ],
            build: (values) => .new(
              landing: values('landing'),
              meeting: values('meeting'),
              rides: values('rides'),
              hotel: values('hotel'),
              policy: values('policy'),
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.bookRide,
          name: 'book_ride',
          description: 'Books the ride [rideId] from the airport and charges its fare to the company card. Returns the booking, to tell the traveller.',
          parameters: [const AgentParameter<String>('rideId', .string)],
          invoke: (args) async {
            final result = await surface.bookRide(args.read('rideId'));

            return AgentResult(result).as(.string);
          },
        ),
        AgentTool(
          surface.messageHost,
          name: 'message_host',
          description: "Texts the meeting's host, in the traveller's name, when the traveller lands and arrives. Returns the message as sent.",
          parameters: [],
          invoke: (args) {
            final result = surface.messageHost();

            return AgentResult(result).as(.string);
          },
        ),
        AgentTool(
          surface.requestEarlyCheckIn,
          name: 'request_early_check_in',
          description: 'Asks the hotel to have the room ready early, for the bags. It costs nothing.',
          parameters: [],
          invoke: (args) {
            surface.requestEarlyCheckIn();
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on ArrivalCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('arrival', arrival),
    if (state.ride == null) .callsWithApproval(bookRide),
    if (!state.hostTold) .callsWithApproval(messageHost),
    if (!state.earlyCheckIn) .calls(requestEarlyCheckIn),
  ];
}
