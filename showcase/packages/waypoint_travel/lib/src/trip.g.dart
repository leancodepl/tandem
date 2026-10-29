// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'trip.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HotelStayCWProxy {
  HotelStay name(String name);

  HotelStay address(String address);

  HotelStay checkIn(DateTime checkIn);

  HotelStay nights(int nights);

  HotelStay nightly(int nightly);

  HotelStay confirmation(String confirmation);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HotelStay(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HotelStay(...).copyWith(id: 12, name: "My name")
  /// ```
  HotelStay call({
    String name,
    String address,
    DateTime checkIn,
    int nights,
    int nightly,
    String confirmation,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfHotelStay.copyWith(...)` or call `instanceOfHotelStay.copyWith.fieldName(value)` for a single field.
class _$HotelStayCWProxyImpl implements _$HotelStayCWProxy {
  const _$HotelStayCWProxyImpl(this._value);

  final HotelStay _value;

  @override
  HotelStay name(String name) => call(name: name);

  @override
  HotelStay address(String address) => call(address: address);

  @override
  HotelStay checkIn(DateTime checkIn) => call(checkIn: checkIn);

  @override
  HotelStay nights(int nights) => call(nights: nights);

  @override
  HotelStay nightly(int nightly) => call(nightly: nightly);

  @override
  HotelStay confirmation(String confirmation) =>
      call(confirmation: confirmation);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HotelStay(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HotelStay(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  HotelStay call({
    Object? name = const $CopyWithPlaceholder(),
    Object? address = const $CopyWithPlaceholder(),
    Object? checkIn = const $CopyWithPlaceholder(),
    Object? nights = const $CopyWithPlaceholder(),
    Object? nightly = const $CopyWithPlaceholder(),
    Object? confirmation = const $CopyWithPlaceholder(),
  }) {
    return HotelStay(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      address: address == const $CopyWithPlaceholder() || address == null
          ? _value.address
          // ignore: cast_nullable_to_non_nullable
          : address as String,
      checkIn: checkIn == const $CopyWithPlaceholder() || checkIn == null
          ? _value.checkIn
          // ignore: cast_nullable_to_non_nullable
          : checkIn as DateTime,
      nights: nights == const $CopyWithPlaceholder() || nights == null
          ? _value.nights
          // ignore: cast_nullable_to_non_nullable
          : nights as int,
      nightly: nightly == const $CopyWithPlaceholder() || nightly == null
          ? _value.nightly
          // ignore: cast_nullable_to_non_nullable
          : nightly as int,
      confirmation:
          confirmation == const $CopyWithPlaceholder() || confirmation == null
          ? _value.confirmation
          // ignore: cast_nullable_to_non_nullable
          : confirmation as String,
    );
  }
}

extension $HotelStayCopyWith on HotelStay {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfHotelStay.copyWith(...)` or `instanceOfHotelStay.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HotelStayCWProxy get copyWith => _$HotelStayCWProxyImpl(this);
}

abstract class _$ItineraryCWProxy {
  Itinerary homebound(Flight homebound);

  Itinerary hotel(HotelStay? hotel);

  Itinerary meetings(List<Meeting> meetings);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Itinerary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Itinerary(...).copyWith(id: 12, name: "My name")
  /// ```
  Itinerary call({Flight homebound, HotelStay? hotel, List<Meeting> meetings});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfItinerary.copyWith(...)` or call `instanceOfItinerary.copyWith.fieldName(value)` for a single field.
class _$ItineraryCWProxyImpl implements _$ItineraryCWProxy {
  const _$ItineraryCWProxyImpl(this._value);

  final Itinerary _value;

  @override
  Itinerary homebound(Flight homebound) => call(homebound: homebound);

  @override
  Itinerary hotel(HotelStay? hotel) => call(hotel: hotel);

  @override
  Itinerary meetings(List<Meeting> meetings) => call(meetings: meetings);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Itinerary(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Itinerary(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Itinerary call({
    Object? homebound = const $CopyWithPlaceholder(),
    Object? hotel = const $CopyWithPlaceholder(),
    Object? meetings = const $CopyWithPlaceholder(),
  }) {
    return Itinerary(
      outbound: _value.outbound,
      homebound: homebound == const $CopyWithPlaceholder() || homebound == null
          ? _value.homebound
          // ignore: cast_nullable_to_non_nullable
          : homebound as Flight,
      hotel: hotel == const $CopyWithPlaceholder()
          ? _value.hotel
          // ignore: cast_nullable_to_non_nullable
          : hotel as HotelStay?,
      meetings: meetings == const $CopyWithPlaceholder() || meetings == null
          ? _value.meetings
          // ignore: cast_nullable_to_non_nullable
          : meetings as List<Meeting>,
    );
  }
}

extension $ItineraryCopyWith on Itinerary {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfItinerary.copyWith(...)` or `instanceOfItinerary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ItineraryCWProxy get copyWith => _$ItineraryCWProxyImpl(this);
}

abstract class _$TripCWProxy {
  Trip id(String id);

  Trip city(String city);

  Trip purpose(String? purpose);

  Trip booked(Itinerary booked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Trip(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Trip(...).copyWith(id: 12, name: "My name")
  /// ```
  Trip call({String id, String city, String? purpose, Itinerary booked});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTrip.copyWith(...)` or call `instanceOfTrip.copyWith.fieldName(value)` for a single field.
class _$TripCWProxyImpl implements _$TripCWProxy {
  const _$TripCWProxyImpl(this._value);

  final Trip _value;

  @override
  Trip id(String id) => call(id: id);

  @override
  Trip city(String city) => call(city: city);

  @override
  Trip purpose(String? purpose) => call(purpose: purpose);

  @override
  Trip booked(Itinerary booked) => call(booked: booked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `Trip(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// Trip(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  Trip call({
    Object? id = const $CopyWithPlaceholder(),
    Object? city = const $CopyWithPlaceholder(),
    Object? purpose = const $CopyWithPlaceholder(),
    Object? booked = const $CopyWithPlaceholder(),
  }) {
    return Trip(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      city: city == const $CopyWithPlaceholder() || city == null
          ? _value.city
          // ignore: cast_nullable_to_non_nullable
          : city as String,
      purpose: purpose == const $CopyWithPlaceholder()
          ? _value.purpose
          // ignore: cast_nullable_to_non_nullable
          : purpose as String?,
      booked: booked == const $CopyWithPlaceholder() || booked == null
          ? _value.booked
          // ignore: cast_nullable_to_non_nullable
          : booked as Itinerary,
    );
  }
}

extension $TripCopyWith on Trip {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTrip.copyWith(...)` or `instanceOfTrip.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TripCWProxy get copyWith => _$TripCWProxyImpl(this);
}
