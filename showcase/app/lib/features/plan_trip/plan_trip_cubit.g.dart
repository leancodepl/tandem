// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'plan_trip_cubit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PlanTripStateCWProxy {
  PlanTripState meetings(List<Meeting> meetings);

  PlanTripState outbound(Flight? outbound);

  PlanTripState homebound(Flight? homebound);

  PlanTripState hotel(Hotel? hotel);

  PlanTripState booking(bool booking);

  PlanTripState marked(Set<PlanTripInput> marked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PlanTripState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PlanTripState(...).copyWith(id: 12, name: "My name")
  /// ```
  PlanTripState call({
    List<Meeting> meetings,
    Flight? outbound,
    Flight? homebound,
    Hotel? hotel,
    bool booking,
    Set<PlanTripInput> marked,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPlanTripState.copyWith(...)` or call `instanceOfPlanTripState.copyWith.fieldName(value)` for a single field.
class _$PlanTripStateCWProxyImpl implements _$PlanTripStateCWProxy {
  const _$PlanTripStateCWProxyImpl(this._value);

  final PlanTripState _value;

  @override
  PlanTripState meetings(List<Meeting> meetings) => call(meetings: meetings);

  @override
  PlanTripState outbound(Flight? outbound) => call(outbound: outbound);

  @override
  PlanTripState homebound(Flight? homebound) => call(homebound: homebound);

  @override
  PlanTripState hotel(Hotel? hotel) => call(hotel: hotel);

  @override
  PlanTripState booking(bool booking) => call(booking: booking);

  @override
  PlanTripState marked(Set<PlanTripInput> marked) => call(marked: marked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PlanTripState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PlanTripState(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PlanTripState call({
    Object? meetings = const $CopyWithPlaceholder(),
    Object? outbound = const $CopyWithPlaceholder(),
    Object? homebound = const $CopyWithPlaceholder(),
    Object? hotel = const $CopyWithPlaceholder(),
    Object? booking = const $CopyWithPlaceholder(),
    Object? marked = const $CopyWithPlaceholder(),
  }) {
    return PlanTripState(
      meetings: meetings == const $CopyWithPlaceholder() || meetings == null
          ? _value.meetings
          // ignore: cast_nullable_to_non_nullable
          : meetings as List<Meeting>,
      outbound: outbound == const $CopyWithPlaceholder()
          ? _value.outbound
          // ignore: cast_nullable_to_non_nullable
          : outbound as Flight?,
      homebound: homebound == const $CopyWithPlaceholder()
          ? _value.homebound
          // ignore: cast_nullable_to_non_nullable
          : homebound as Flight?,
      hotel: hotel == const $CopyWithPlaceholder()
          ? _value.hotel
          // ignore: cast_nullable_to_non_nullable
          : hotel as Hotel?,
      booking: booking == const $CopyWithPlaceholder() || booking == null
          ? _value.booking
          // ignore: cast_nullable_to_non_nullable
          : booking as bool,
      marked: marked == const $CopyWithPlaceholder() || marked == null
          ? _value.marked
          // ignore: cast_nullable_to_non_nullable
          : marked as Set<PlanTripInput>,
    );
  }
}

extension $PlanTripStateCopyWith on PlanTripState {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPlanTripState.copyWith(...)` or `instanceOfPlanTripState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PlanTripStateCWProxy get copyWith => _$PlanTripStateCWProxyImpl(this);
}

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
          description:
              'Adds a meeting of the trip, from [start] to [end], at [place].',
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
                  id: 'package:waypoint/features/plan_trip/plan_trip_cubit.dart#HotelOption',
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
      .calls(findFlights),
      .calls(setOutboundFlight),
      .calls(setHomeboundFlight),
      .calls(findHotels),
      .calls(setHotel),
    ],
  ];
}
