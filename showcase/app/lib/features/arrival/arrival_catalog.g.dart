// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'arrival_catalog.dart';

// **************************************************************************
// CatalogGenerator
// **************************************************************************

mixin _$ArrivalCatalog implements AgentCatalog {
  @override
  String get guidelines =>
      "Start with one ArrivalCard titled for the day. Show the next meeting as a NextStop, the ways from the airport as one RideOption per item of /arrival/rides, the meeting's host as a HostNote and the hotel as a HotelNote. Give a button its action only when its method is among your tools; leave it out otherwise. Put first what the traveller needs first.";

  @override
  List<Map<String, Object?>> get example => const [
    {
      'id': 'root',
      'component': 'ArrivalCard',
      'title': 'After you land',
      'children': ['next', 'rides', 'host', 'hotel'],
    },
    {
      'id': 'next',
      'component': 'NextStop',
      'title': {'path': '/arrival/meeting/title'},
      'place': {'path': '/arrival/meeting/place'},
      'start': {'path': '/arrival/meeting/start'},
    },
    {
      'id': 'rides',
      'component': 'ArrivalColumn',
      'children': {'componentId': 'ride', 'path': '/arrival/rides'},
    },
    {
      'id': 'ride',
      'component': 'RideOption',
      'mode': {'path': 'mode'},
      'minutes': {'path': 'minutes'},
      'fare': {'path': 'fare'},
      'arrives': {'path': 'arrives'},
      'booked': {'path': 'booked'},
      'overPolicy': {'path': 'overPolicy'},
      'onBook': {
        'action': {
          'event': {
            'name': 'book_ride',
            'context': {
              'rideId': {'path': 'id'},
            },
          },
        },
      },
    },
    {
      'id': 'host',
      'component': 'HostNote',
      'name': {'path': '/arrival/meeting/host'},
      'told': {'path': '/arrival/meeting/hostTold'},
      'onText': {
        'action': {
          'event': {'name': 'message_host'},
        },
      },
    },
    {
      'id': 'hotel',
      'component': 'HotelNote',
      'name': {'path': '/arrival/hotel/name'},
      'checkIn': {'path': '/arrival/hotel/checkIn'},
      'roomReady': {'path': '/arrival/hotel/roomReady'},
      'onEarlyCheckIn': {
        'action': {
          'event': {'name': 'request_early_check_in'},
        },
      },
    },
  ];

  @override
  List<AgentComponent> get components => [
    AgentComponent<ArrivalCard>.of(
      name: 'ArrivalCard',
      description: 'A card with a title over its parts, such as what to do after landing.',
      properties: (property) => [
        property('title', (widget) => widget.title).value(.string),
        property.children('children'),
      ],
      build: (args) => ArrivalCard(
        title: args.value('title'),
        children: args.children('children'),
      ),
    ),
    AgentComponent<ArrivalColumn>.of(
      name: 'ArrivalColumn',
      description:
          'Parts one below another, such as the ways from the airport.',
      properties: (property) => [property.children('children')],
      build: (args) => ArrivalColumn(children: args.children('children')),
    ),
    AgentComponent<NextStop>.of(
      name: 'NextStop',
      description: 'The next meeting: its title, where and when it starts.',
      properties: (property) => [
        property('title', (widget) => widget.title).value(.string),
        property('place', (widget) => widget.place).value(.string),
        property('start', (widget) => widget.start).value(.dateTime),
      ],
      build: (args) => NextStop(
        title: args.value('title'),
        place: args.value('place'),
        start: args.value('start'),
      ),
    ),
    AgentComponent<RideOption>.of(
      name: 'RideOption',
      description: 'One way from the airport: how, how long, the fare and when it arrives, with a button to book it, or its booking once booked.',
      properties: (property) => [
        property('mode', (widget) => widget.mode).value(
          .enumeration([
            .taxi,
            .train,
          ], id: 'package:waypoint_travel/src/arrival.dart#RideMode'),
        ),
        property('minutes', (widget) => widget.minutes).value(.integer),
        property('fare', (widget) => widget.fare).value(.integer),
        property('arrives', (widget) => widget.arrives).value(.dateTime),
        property(
          'booked',
          (widget) => widget.booked,
        ).value(.nullable(.string), required: false),
        property(
          'overPolicy',
          (widget) => widget.overPolicy,
        ).value(.boolean, required: false),
        property.press('onBook', required: false),
      ],
      build: (args) => RideOption(
        mode: args.value('mode'),
        minutes: args.value('minutes'),
        fare: args.value('fare'),
        arrives: args.value('arrives'),
        booked: args.value('booked'),
        overPolicy: args.valueOr('overPolicy', false),
        onBook: args.pressOrNull('onBook'),
      ),
    ),
    AgentComponent<HostNote>.of(
      name: 'HostNote',
      description: 'The person who expects the traveller, with a button to text them when the traveller arrives.',
      properties: (property) => [
        property('name', (widget) => widget.name).value(.string),
        property('told', (widget) => widget.told).value(.boolean),
        property.press('onText', required: false),
      ],
      build: (args) => HostNote(
        name: args.value('name'),
        told: args.value('told'),
        onText: args.pressOrNull('onText'),
      ),
    ),
    AgentComponent<HotelNote>.of(
      name: 'HotelNote',
      description: 'The hotel: when the room is ready, with a button to ask for it early.',
      properties: (property) => [
        property(
          'name',
          (widget) => widget.name,
        ).value(.nullable(.string), required: false),
        property(
          'checkIn',
          (widget) => widget.checkIn,
        ).value(.nullable(.dateTime), required: false),
        property(
          'roomReady',
          (widget) => widget.roomReady,
        ).value(.nullable(.dateTime), required: false),
        property.press('onEarlyCheckIn', required: false),
      ],
      build: (args) => HotelNote(
        name: args.value('name'),
        checkIn: args.value('checkIn'),
        roomReady: args.value('roomReady'),
        onEarlyCheckIn: args.pressOrNull('onEarlyCheckIn'),
      ),
    ),
  ];
}
