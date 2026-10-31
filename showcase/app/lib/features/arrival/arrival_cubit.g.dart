// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'arrival_cubit.dart';

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
    if (_canBookRide) .callsWithApproval(bookRide),
    if (!_arranged.hostTold) .callsWithApproval(messageHost),
    if (trip.booked.hotel != null && !_arranged.earlyCheckIn)
      .calls(requestEarlyCheckIn),
  ];
}
