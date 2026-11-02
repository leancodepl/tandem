import 'package:waypoint_travel/src/hotel.dart';
import 'package:waypoint_travel/src/value_objects.dart';

/// The hotels Waypoint can book, with how far each is from the places the
/// demo's meetings are at. A real app would ask its travel provider.
final class const HotelSearch() {
  static final _hotels = [
    Hotel(
      id: HotelId('ringstrasse-grand'),
      name: 'Ringstrasse Grand',
      city: 'Vienna',
      address: 'Kärntner Ring 9, 1010 Vienna',
      nightly: wholeMoney(245),
      walkDuration: const Duration(minutes: 4),
    ),
    Hotel(
      id: HotelId('spittelberg'),
      name: 'Spittelberg Boutique Hotel',
      city: 'Vienna',
      address: 'Spittelberggasse 12, 1070 Vienna',
      nightly: wholeMoney(138),
      walkDuration: const Duration(minutes: 8),
    ),
    Hotel(
      id: HotelId('naschmarkt-rooms'),
      name: 'Naschmarkt Rooms',
      city: 'Vienna',
      address: 'Linke Wienzeile 30, 1060 Vienna',
      nightly: wholeMoney(119),
      walkDuration: const Duration(minutes: 22),
    ),
    Hotel(
      id: HotelId('spree-loft'),
      name: 'Spree Loft Hotel',
      city: 'Berlin',
      address: 'Am Wriezener Bahnhof 2, Berlin',
      nightly: wholeMoney(122),
      walkDuration: const Duration(minutes: 12),
    ),
    Hotel(
      id: HotelId('oberbaum-suites'),
      name: 'Oberbaum Suites',
      city: 'Berlin',
      address: 'Stralauer Allee 3, 10245 Berlin',
      nightly: wholeMoney(189),
      walkDuration: const Duration(minutes: 18),
    ),
    Hotel(
      id: HotelId('havnegade-loft'),
      name: 'Havnegade Loft',
      city: 'Copenhagen',
      address: 'Havnegade 44, 1058 Copenhagen',
      nightly: wholeMoney(168),
      walkDuration: const Duration(minutes: 25),
    ),
    Hotel(
      id: HotelId('kalvebod-rooms'),
      name: 'Kalvebod Rooms',
      city: 'Copenhagen',
      address: 'Kalvebod Brygge 10, 1560 Copenhagen',
      nightly: wholeMoney(139),
      walkDuration: const Duration(minutes: 5),
    ),
  ];

  List<Hotel> inCity(String city) => [
    for (final hotel in _hotels)
      if (hotel.city.toLowerCase() == city.trim().toLowerCase()) hotel,
  ];

  Hotel? find(HotelId id) =>
      _hotels.where((hotel) => hotel.id == id).firstOrNull;
}
