// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'plan_trip_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$PlanTripCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as PlanTripCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.plan).as(
          'plan',
          'The new trip as the traveller sees it in the form, with what is still missing.',
          .object(
            id: 'package:waypoint/features/plan_trip/plan_trip_summary.dart#PlanSummary',
            fields: (field) => [
              field(
                'city',
                (value) => value.city,
                required: false,
              ).as(.nullable(.string)),
              field(
                'purpose',
                (value) => value.purpose,
                required: false,
              ).as(.nullable(.string)),
              field('meetings', (value) => value.meetings).as(
                .list(
                  .object(
                    id: 'package:waypoint/features/trip/trip_summary.dart#MeetingSummary',
                    fields: (field) => [
                      field('id', (value) => value.id).as(.string),
                      field('title', (value) => value.title).as(.string),
                      field('place', (value) => value.place).as(.string),
                      field('start', (value) => value.start).as(.string),
                      field('end', (value) => value.end).as(.string),
                    ],
                    build: (values) => .new(
                      id: values('id'),
                      title: values('title'),
                      place: values('place'),
                      start: values('start'),
                      end: values('end'),
                    ),
                  ),
                ),
              ),
              field('outbound', (value) => value.outbound, required: false).as(
                .nullable(
                  .object(
                    id: 'package:waypoint/features/trip/trip_summary.dart#FlightSummary',
                    fields: (field) => [
                      field('number', (value) => value.number).as(.string),
                      field('origin', (value) => value.origin).as(.string),
                      field(
                        'destination',
                        (value) => value.destination,
                      ).as(.string),
                      field('departs', (value) => value.departs).as(.string),
                      field('arrives', (value) => value.arrives).as(.string),
                      field('fare', (value) => value.fare).as(.integer),
                    ],
                    build: (values) => .new(
                      number: values('number'),
                      origin: values('origin'),
                      destination: values('destination'),
                      departs: values('departs'),
                      arrives: values('arrives'),
                      fare: values('fare'),
                    ),
                  ),
                ),
              ),
              field(
                'homebound',
                (value) => value.homebound,
                required: false,
              ).as(
                .nullable(
                  .object(
                    id: 'package:waypoint/features/trip/trip_summary.dart#FlightSummary',
                    fields: (field) => [
                      field('number', (value) => value.number).as(.string),
                      field('origin', (value) => value.origin).as(.string),
                      field(
                        'destination',
                        (value) => value.destination,
                      ).as(.string),
                      field('departs', (value) => value.departs).as(.string),
                      field('arrives', (value) => value.arrives).as(.string),
                      field('fare', (value) => value.fare).as(.integer),
                    ],
                    build: (values) => .new(
                      number: values('number'),
                      origin: values('origin'),
                      destination: values('destination'),
                      departs: values('departs'),
                      arrives: values('arrives'),
                      fare: values('fare'),
                    ),
                  ),
                ),
              ),
              field('hotel', (value) => value.hotel, required: false).as(
                .nullable(
                  .object(
                    id: 'package:waypoint/features/plan_trip/plan_trip_summary.dart#PlannedHotel',
                    fields: (field) => [
                      field('name', (value) => value.name).as(.string),
                      field('nightly', (value) => value.nightly).as(.integer),
                      field('nights', (value) => value.nights).as(.integer),
                    ],
                    build: (values) => .new(
                      name: values('name'),
                      nightly: values('nightly'),
                      nights: values('nights'),
                    ),
                  ),
                ),
              ),
              field(
                'missing',
                (value) => value.missing,
                description: 'What the form still needs before the traveller can book it.',
              ).as(.list(.string)),
              field('total', (value) => value.total).as(.integer),
            ],
            build: (values) => .new(
              city: values('city'),
              purpose: values('purpose'),
              meetings: values('meetings'),
              outbound: values('outbound'),
              homebound: values('homebound'),
              hotel: values('hotel'),
              missing: values('missing'),
              total: values('total'),
            ),
          ),
        ),
        AgentView.of(() => surface.policy)
            .as('policy', "The company's rules for every trip.", .string),
      ],
      calls: [
        AgentTool(
          surface.setCity,
          name: 'set_city',
          description:
              'Sets the city of the trip: Berlin, Copenhagen or Vienna.',
          parameters: [const AgentParameter<String>('city', .string)],
          invoke: (args) {
            surface.setCity(args.read('city'));
            return null;
          },
        ),
        AgentTool(
          surface.setPurpose,
          name: 'set_purpose',
          description:
              'Sets what the trip is for, such as "Discovery · Alpenlicht".',
          parameters: [const AgentParameter<String>('purpose', .string)],
          invoke: (args) {
            surface.setPurpose(args.read('purpose'));
            return null;
          },
        ),
        AgentTool(
          surface.addMeeting,
          name: 'add_meeting',
          description: 'Adds a meeting from [start] to [end] at [place]. An identical meeting already in the plan is kept once.',
          parameters: [
            const AgentParameter<String>('title', .string),
            const AgentParameter<String>('place', .string),
            const AgentParameter<DateTime>('start', .dateTime),
            const AgentParameter<DateTime>('end', .dateTime),
          ],
          invoke: (args) {
            surface.addMeeting(
              args.read('title'),
              args.read('place'),
              args.read('start'),
              args.read('end'),
            );
            return null;
          },
        ),
        AgentTool(
          surface.updateMeeting,
          name: 'update_meeting',
          description:
              'Updates the existing meeting [meetingId], keeping its identity.',
          parameters: [
            const AgentParameter<String>('meetingId', .string),
            const AgentParameter<String>('title', .string),
            const AgentParameter<String>('place', .string),
            const AgentParameter<DateTime>('start', .dateTime),
            const AgentParameter<DateTime>('end', .dateTime),
          ],
          invoke: (args) {
            surface.updateMeeting(
              args.read('meetingId'),
              args.read('title'),
              args.read('place'),
              args.read('start'),
              args.read('end'),
            );
            return null;
          },
        ),
        AgentTool(
          surface.removeMeeting,
          name: 'remove_meeting',
          description: 'Removes the meeting [meetingId] from the plan.',
          parameters: [const AgentParameter<String>('meetingId', .string)],
          invoke: (args) {
            surface.removeMeeting(args.read('meetingId'));
            return null;
          },
        ),
        AgentTool(
          surface.findFlights,
          name: 'find_flights',
          description: "Finds the flights from [origin] to [destination] on [date], with their fares in euros and why the trip or the policy rules one out. Airports are IATA codes: WAW for Warsaw, BER, CPH and VIE for the trip's city.",
          parameters: [
            const AgentParameter<String>('origin', .string),
            const AgentParameter<String>('destination', .string),
            const AgentParameter<DateTime>('date', .dateTime),
          ],
          invoke: (args) {
            final result = surface.findFlights(
              args.read('origin'),
              args.read('destination'),
              args.read('date'),
            );

            return AgentResult(result).as(
              .list(
                .object(
                  id: 'package:waypoint/common/tandem/flight_option.dart#FlightOption',
                  description:
                      'A flight as find_flights gives it to the agent.',
                  fields: (field) => [
                    field('number', (value) => value.number).as(.string),
                    field('departs', (value) => value.departs).as(.string),
                    field('arrives', (value) => value.arrives).as(.string),
                    field('fare', (value) => value.fare).as(.integer),
                    field(
                      'unavailable',
                      (value) => value.unavailable,
                      description: 'Why the traveller cannot take it, or null when they can.',
                      required: false,
                    ).as(.nullable(.string)),
                  ],
                  build: (values) => .new(
                    number: values('number'),
                    departs: values('departs'),
                    arrives: values('arrives'),
                    fare: values('fare'),
                    unavailable: values('unavailable'),
                  ),
                ),
              ),
            );
          },
        ),
        AgentTool(
          surface.setOutboundFlight,
          name: 'set_outbound_flight',
          description: 'Puts the traveller on flight [number] from Warsaw on [date], one that find_flights gives.',
          parameters: [
            const AgentParameter<String>('number', .string),
            const AgentParameter<DateTime>('date', .dateTime),
          ],
          invoke: (args) {
            surface.setOutboundFlight(args.read('number'), args.read('date'));
            return null;
          },
        ),
        AgentTool(
          surface.setHomeboundFlight,
          name: 'set_homebound_flight',
          description: 'Puts the traveller on flight [number] home to Warsaw on [date], one that find_flights gives.',
          parameters: [
            const AgentParameter<String>('number', .string),
            const AgentParameter<DateTime>('date', .dateTime),
          ],
          invoke: (args) {
            surface.setHomeboundFlight(args.read('number'), args.read('date'));
            return null;
          },
        ),
        AgentTool(
          surface.findHotels,
          name: 'find_hotels',
          description: 'Finds the hotels in [city], with their price a night, the minutes on foot to the meetings and why the trip or the policy rules one out.',
          parameters: [const AgentParameter<String>('city', .string)],
          invoke: (args) {
            final result = surface.findHotels(args.read('city'));

            return AgentResult(result).as(
              .list(
                .object(
                  id: 'package:waypoint/features/plan_trip/hotel_option.dart#HotelOption',
                  description: 'A hotel as find_hotels gives it to the agent.',
                  fields: (field) => [
                    field('id', (value) => value.id).as(.string),
                    field('name', (value) => value.name).as(.string),
                    field('nightly', (value) => value.nightly).as(.integer),
                    field(
                      'walkMinutes',
                      (value) => value.walkMinutes,
                    ).as(.integer),
                    field(
                      'unavailable',
                      (value) => value.unavailable,
                      description: 'Why the traveller cannot take it, or null when they can.',
                      required: false,
                    ).as(.nullable(.string)),
                  ],
                  build: (values) => .new(
                    id: values('id'),
                    name: values('name'),
                    nightly: values('nightly'),
                    walkMinutes: values('walkMinutes'),
                    unavailable: values('unavailable'),
                  ),
                ),
              ),
            );
          },
        ),
        AgentTool(
          surface.setHotel,
          name: 'set_hotel',
          description: 'Books the traveller into the hotel [hotelId], one that find_hotels gives, from the day they land to the day they fly home.',
          parameters: [const AgentParameter<String>('hotelId', .string)],
          invoke: (args) {
            surface.setHotel(args.read('hotelId'));
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on PlanTripCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('plan', plan),
    .seesAs('policy', policy),
    if (!state.booking) ...[
      .calls(setCity),
      .calls(setPurpose),
      .calls(addMeeting),
      .calls(updateMeeting),
      .calls(removeMeeting),
      .calls(findFlights),
      .calls(setOutboundFlight),
      .calls(setHomeboundFlight),
      .calls(findHotels),
      .calls(setHotel),
    ],
  ];
}
