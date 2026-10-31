// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'arrival_arrangements_cubit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ArrivalStateCWProxy {
  ArrivalState ride(RideBooking? ride);

  ArrivalState pendingRide(RideId? pendingRide);

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
  ArrivalState call({
    RideBooking? ride,
    RideId? pendingRide,
    bool hostTold,
    bool earlyCheckIn,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfArrivalState.copyWith(...)` or call `instanceOfArrivalState.copyWith.fieldName(value)` for a single field.
class _$ArrivalStateCWProxyImpl implements _$ArrivalStateCWProxy {
  const _$ArrivalStateCWProxyImpl(this._value);

  final ArrivalState _value;

  @override
  ArrivalState ride(RideBooking? ride) => call(ride: ride);

  @override
  ArrivalState pendingRide(RideId? pendingRide) =>
      call(pendingRide: pendingRide);

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
    Object? pendingRide = const $CopyWithPlaceholder(),
    Object? hostTold = const $CopyWithPlaceholder(),
    Object? earlyCheckIn = const $CopyWithPlaceholder(),
  }) {
    return ArrivalState(
      ride: ride == const $CopyWithPlaceholder()
          ? _value.ride
          // ignore: cast_nullable_to_non_nullable
          : ride as RideBooking?,
      pendingRide: pendingRide == const $CopyWithPlaceholder()
          ? _value.pendingRide
          // ignore: cast_nullable_to_non_nullable
          : pendingRide as RideId?,
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
