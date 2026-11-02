import 'package:waypoint_travel/waypoint_travel.dart';

Traveller demoTraveller() =>
    Traveller(name: 'Ola Brandt', today: DateTime(2026, 10, 24));

List<Trip> demoTrips() => [_paris(), _berlin(), _copenhagen()];

const _flights = FlightSearch();

Trip _paris() {
  final tuesday = DateTime(2026, 9, 15);
  final wednesday = DateTime(2026, 9, 16);
  return Trip(
    id: TripId('paris'),
    city: 'Paris',
    purpose: 'Workshop · Maison Lumen',
    booked: Itinerary(
      outbound: _flight('WA 631', tuesday),
      homebound: _flight('WA 636', wednesday),
      hotel: HotelStay.atNightlyRate(
        name: 'Hôtel du Canal',
        address: 'Quai de Valmy 88, 75010 Paris',
        checkIn: DateTime(2026, 9, 15, 15),
        nights: NightCount(1),
        nightlyRate: wholeMoney(149),
        confirmation: BookingReference('77310452'),
      ),
      meetings: [
        Meeting(
          id: MeetingId('lumen-workshop'),
          title: 'Workshop with Maison Lumen',
          place: 'Maison Lumen, Rue de Paradis 41',
          start: DateTime(2026, 9, 15, 13),
          end: DateTime(2026, 9, 15, 18),
        ),
        Meeting(
          id: MeetingId('lumen-review'),
          title: 'Design review',
          place: 'Maison Lumen, Rue de Paradis 41',
          start: DateTime(2026, 9, 16, 10),
          end: DateTime(2026, 9, 16, 15),
        ),
      ],
    ),
  );
}

Trip _berlin() {
  final wednesday = DateTime(2026, 10, 28);
  final thursday = DateTime(2026, 10, 29);
  return Trip(
    id: TripId('berlin'),
    city: 'Berlin',
    purpose: 'Client work · Studio Kraft',
    booked: Itinerary(
      outbound: _flight('WA 379', wednesday),
      homebound: _flight('WA 388', thursday),
      hotel: HotelStay.atNightlyRate(
        name: 'Spree Loft Hotel',
        address: 'Am Wriezener Bahnhof 2, Berlin',
        checkIn: DateTime(2026, 10, 28, 15),
        nights: NightCount(1),
        nightlyRate: wholeMoney(122),
        confirmation: BookingReference('84213907'),
      ),
      meetings: [
        Meeting(
          id: MeetingId('kickoff'),
          title: 'Kickoff with Studio Kraft',
          place: 'Studio Kraft, Köpenicker Str. 70',
          start: DateTime(2026, 10, 28, 13),
          end: DateTime(2026, 10, 28, 14, 30),
        ),
        Meeting(
          id: MeetingId('dinner'),
          title: 'Dinner with the Kraft team',
          place: 'Café Ostkreuz',
          start: DateTime(2026, 10, 28, 19, 30),
          end: DateTime(2026, 10, 28, 21, 30),
        ),
        Meeting(
          id: MeetingId('workshop'),
          title: 'Design workshop',
          place: 'Studio Kraft, Köpenicker Str. 70',
          start: DateTime(2026, 10, 29, 10),
          end: DateTime(2026, 10, 29, 16),
        ),
      ],
    ),
  );
}

Trip _copenhagen() {
  final wednesday = DateTime(2026, 11, 18);
  final thursday = DateTime(2026, 11, 19);
  return Trip(
    id: TripId('copenhagen'),
    city: 'Copenhagen',
    purpose: 'Pitch · Nordlys Energy',
    booked: Itinerary(
      outbound: _flight('WA 471', wednesday),
      homebound: _flight('WA 478', thursday),
      meetings: [
        Meeting(
          id: MeetingId('pitch'),
          title: 'Pitch to Nordlys Energy',
          place: 'Nordlys Energy, Kalvebod Brygge 39',
          start: DateTime(2026, 11, 18, 14),
          end: DateTime(2026, 11, 18, 16),
        ),
        Meeting(
          id: MeetingId('review'),
          title: 'Design review with the Nordlys team',
          place: 'Nordlys Energy, Kalvebod Brygge 39',
          start: DateTime(2026, 11, 19, 10),
          end: DateTime(2026, 11, 19, 12, 30),
        ),
      ],
    ),
  );
}

Flight _flight(String number, DateTime day) => switch (_flights.find(
  FlightNumber(number),
  day,
)) {
  final flight? => flight,
  null => throw ArgumentError.value(number, 'number', 'Not in the timetable'),
};
