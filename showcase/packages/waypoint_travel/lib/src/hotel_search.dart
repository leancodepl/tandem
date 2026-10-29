import 'package:equatable/equatable.dart';

/// The hotels Waypoint can book, with how far each is from the places the
/// demo's meetings are at. A real app would ask its travel provider.
final class const HotelSearch() {
  static const _hotels = [
    Hotel(
      id: 'ringstrasse-grand',
      name: 'Ringstrasse Grand',
      city: 'Vienna',
      address: 'Kärntner Ring 9, 1010 Vienna',
      nightly: 245,
      walkMinutes: 4,
    ),
    Hotel(
      id: 'spittelberg',
      name: 'Spittelberg Boutique Hotel',
      city: 'Vienna',
      address: 'Spittelberggasse 12, 1070 Vienna',
      nightly: 138,
      walkMinutes: 8,
    ),
    Hotel(
      id: 'naschmarkt-rooms',
      name: 'Naschmarkt Rooms',
      city: 'Vienna',
      address: 'Linke Wienzeile 30, 1060 Vienna',
      nightly: 119,
      walkMinutes: 22,
    ),
    Hotel(
      id: 'spree-loft',
      name: 'Spree Loft Hotel',
      city: 'Berlin',
      address: 'Am Wriezener Bahnhof 2, Berlin',
      nightly: 122,
      walkMinutes: 12,
    ),
    Hotel(
      id: 'oberbaum-suites',
      name: 'Oberbaum Suites',
      city: 'Berlin',
      address: 'Stralauer Allee 3, 10245 Berlin',
      nightly: 189,
      walkMinutes: 18,
    ),
    Hotel(
      id: 'havnegade-loft',
      name: 'Havnegade Loft',
      city: 'Copenhagen',
      address: 'Havnegade 44, 1058 Copenhagen',
      nightly: 168,
      walkMinutes: 25,
    ),
    Hotel(
      id: 'kalvebod-rooms',
      name: 'Kalvebod Rooms',
      city: 'Copenhagen',
      address: 'Kalvebod Brygge 10, 1560 Copenhagen',
      nightly: 139,
      walkMinutes: 5,
    ),
  ];

  List<Hotel> inCity(String city) => [
    for (final hotel in _hotels)
      if (hotel.city.toLowerCase() == city.trim().toLowerCase()) hotel,
  ];

  Hotel? find(String id) =>
      _hotels.where((hotel) => hotel.id == id).firstOrNull;
}

final class const Hotel({
  required final String id,
  required final String name,
  required final String city,
  required final String address,
  required final int nightly,

  /// On foot to the meetings of the trip.
  required final int walkMinutes,
}) with Equatable {
  @override
  List<Object?> get props => [id, name, city, address, nightly, walkMinutes];
}
