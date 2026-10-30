// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'trip_cubit.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$TripCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as TripCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.trip).as(
          'trip',
          'The trip as the traveller sees it on the screen, with what is not booked yet.',
          .object(
            id: 'package:waypoint/features/trip/trip_summary.dart#TripSummary',
            fields: (field) => [
              field('today', (value) => value.today).as(.string),
              field('traveller', (value) => value.traveller).as(.string),
              field('purpose', (value) => value.purpose).as(.string),
              field('city', (value) => value.city).as(.string),
              field('outbound', (value) => value.outbound).as(
                .object(
                  id: 'package:waypoint/features/trip/trip_summary.dart#FlightSummary',
                  fields: (field) => [
                    field('number', (value) => value.number).as(.string),
                    field('from', (value) => value.from).as(.string),
                    field('to', (value) => value.to).as(.string),
                    field('departs', (value) => value.departs).as(.string),
                    field('arrives', (value) => value.arrives).as(.string),
                    field('fare', (value) => value.fare).as(.integer),
                  ],
                  build: (values) => .new(
                    number: values('number'),
                    from: values('from'),
                    to: values('to'),
                    departs: values('departs'),
                    arrives: values('arrives'),
                    fare: values('fare'),
                  ),
                ),
              ),
              field('homebound', (value) => value.homebound).as(
                .object(
                  id: 'package:waypoint/features/trip/trip_summary.dart#FlightSummary',
                  fields: (field) => [
                    field('number', (value) => value.number).as(.string),
                    field('from', (value) => value.from).as(.string),
                    field('to', (value) => value.to).as(.string),
                    field('departs', (value) => value.departs).as(.string),
                    field('arrives', (value) => value.arrives).as(.string),
                    field('fare', (value) => value.fare).as(.integer),
                  ],
                  build: (values) => .new(
                    number: values('number'),
                    from: values('from'),
                    to: values('to'),
                    departs: values('departs'),
                    arrives: values('arrives'),
                    fare: values('fare'),
                  ),
                ),
              ),
              field('hotel', (value) => value.hotel, required: false).as(
                .nullable(
                  .object(
                    id: 'package:waypoint/features/trip/trip_summary.dart#HotelSummary',
                    fields: (field) => [
                      field('name', (value) => value.name).as(.string),
                      field('checkIn', (value) => value.checkIn).as(.string),
                      field('checkOut', (value) => value.checkOut).as(.string),
                      field('nights', (value) => value.nights).as(.integer),
                      field('nightly', (value) => value.nightly).as(.integer),
                    ],
                    build: (values) => .new(
                      name: values('name'),
                      checkIn: values('checkIn'),
                      checkOut: values('checkOut'),
                      nights: values('nights'),
                      nightly: values('nightly'),
                    ),
                  ),
                ),
              ),
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
              field(
                'warnings',
                (value) => value.warnings,
                description:
                    'What does not fit together, as the screen warns about it.',
              ).as(.list(.string)),
              field(
                'unbookedChanges',
                (value) => value.unbookedChanges,
                description: 'Changed on the screen, not booked yet.',
              ).as(
                .list(
                  .object(
                    id: 'package:waypoint/features/trip/trip_summary.dart#ChangeSummary',
                    fields: (field) => [
                      field('what', (value) => value.what).as(.string),
                      field('now', (value) => value.now).as(.string),
                      field('was', (value) => value.was).as(.string),
                      field('cost', (value) => value.cost).as(.integer),
                    ],
                    build: (values) => .new(
                      what: values('what'),
                      now: values('now'),
                      was: values('was'),
                      cost: values('cost'),
                    ),
                  ),
                ),
              ),
              field('unbookedCost', (value) => value.unbookedCost).as(.integer),
            ],
            build: (values) => .new(
              today: values('today'),
              traveller: values('traveller'),
              purpose: values('purpose'),
              city: values('city'),
              outbound: values('outbound'),
              homebound: values('homebound'),
              hotel: values('hotel'),
              meetings: values('meetings'),
              warnings: values('warnings'),
              unbookedChanges: values('unbookedChanges'),
              unbookedCost: values('unbookedCost'),
            ),
          ),
        ),
      ],
      calls: [
        AgentTool(
          surface.findFlights,
          name: 'find_flights',
          description: 'Finds the flights from [origin] to [destination] on [date], with their fares in euros. Airports are IATA codes: WAW for Warsaw, BER for Berlin.',
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
                  id: 'package:waypoint_travel/src/flight_search.dart#FlightOption',
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
          surface.moveMeeting,
          name: 'move_meeting',
          description: "Moves the meeting [meetingId] to start at [start], keeping its length. Meetings are in the traveller's calendar, so moving one books nothing.",
          parameters: [
            const AgentParameter<String>('meetingId', .string),
            const AgentParameter<DateTime>('start', .dateTime),
          ],
          invoke: (args) {
            surface.moveMeeting(args.read('meetingId'), args.read('start'));
            return null;
          },
        ),
        AgentTool(
          surface.setHomeboundFlight,
          name: 'set_homebound_flight',
          description: 'Puts the traveller on flight [number] home on [date], one that find_flights gives. Nothing is booked until book_changes.',
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
          surface.setHotelNights,
          name: 'set_hotel_nights',
          description: 'Sets how many nights the traveller stays at the hotel, counted from the check-in. Nothing is booked until book_changes.',
          parameters: [const AgentParameter<int>('nights', .integer)],
          invoke: (args) {
            surface.setHotelNights(args.read('nights'));
            return null;
          },
        ),
        AgentTool(
          surface.bookChanges,
          name: 'book_changes',
          description: 'Books every change exactly as it is on the screen and charges its cost to the company card. Returns what was booked, to tell the traveller.',
          parameters: [],
          invoke: (args) async {
            final result = await surface.bookChanges();

            return AgentResult(result).as(
              .object(
                id: 'package:waypoint/features/trip/trip_cubit.dart#Booked',
                description: 'What book_changes booked.',
                fields: (field) => [
                  field(
                    'confirmation',
                    (value) => value.confirmation,
                  ).as(.string),
                  field(
                    'changes',
                    (value) => value.changes,
                    description: 'Each booking that changed, as the screen shows it now.',
                  ).as(.list(.string)),
                  field(
                    'charged',
                    (value) => value.charged,
                    description: 'Charged to the company card, in euros.',
                  ).as(.integer),
                ],
                build: (values) => .new(
                  confirmation: values('confirmation'),
                  changes: values('changes'),
                  charged: values('charged'),
                ),
              ),
            );
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

extension on TripCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('trip', trip),
    .calls(findFlights),
    .calls(moveMeeting),
    .calls(setHomeboundFlight),
    .calls(setHotelNights),
    if (bookingChanges.isNotEmpty && !state.booking && changesBreach == null)
      .callsWithApproval(bookChanges),
  ];
}
