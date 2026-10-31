// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'arrival_arrangements_cubit.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ArrivalArrangementsCWProxy {
  ArrivalArrangements ride(RideBooking? ride);

  ArrivalArrangements pendingRide(RideId? pendingRide);

  ArrivalArrangements hostMessage(SentHostMessage? hostMessage);

  ArrivalArrangements earlyCheckIn(EarlyCheckIn? earlyCheckIn);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ArrivalArrangements(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ArrivalArrangements(...).copyWith(id: 12, name: "My name")
  /// ```
  ArrivalArrangements call({
    RideBooking? ride,
    RideId? pendingRide,
    SentHostMessage? hostMessage,
    EarlyCheckIn? earlyCheckIn,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfArrivalArrangements.copyWith(...)` or call `instanceOfArrivalArrangements.copyWith.fieldName(value)` for a single field.
class _$ArrivalArrangementsCWProxyImpl implements _$ArrivalArrangementsCWProxy {
  const _$ArrivalArrangementsCWProxyImpl(this._value);

  final ArrivalArrangements _value;

  @override
  ArrivalArrangements ride(RideBooking? ride) => call(ride: ride);

  @override
  ArrivalArrangements pendingRide(RideId? pendingRide) =>
      call(pendingRide: pendingRide);

  @override
  ArrivalArrangements hostMessage(SentHostMessage? hostMessage) =>
      call(hostMessage: hostMessage);

  @override
  ArrivalArrangements earlyCheckIn(EarlyCheckIn? earlyCheckIn) =>
      call(earlyCheckIn: earlyCheckIn);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ArrivalArrangements(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ArrivalArrangements(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ArrivalArrangements call({
    Object? ride = const $CopyWithPlaceholder(),
    Object? pendingRide = const $CopyWithPlaceholder(),
    Object? hostMessage = const $CopyWithPlaceholder(),
    Object? earlyCheckIn = const $CopyWithPlaceholder(),
  }) {
    return ArrivalArrangements(
      ride: ride == const $CopyWithPlaceholder()
          ? _value.ride
          // ignore: cast_nullable_to_non_nullable
          : ride as RideBooking?,
      pendingRide: pendingRide == const $CopyWithPlaceholder()
          ? _value.pendingRide
          // ignore: cast_nullable_to_non_nullable
          : pendingRide as RideId?,
      hostMessage: hostMessage == const $CopyWithPlaceholder()
          ? _value.hostMessage
          // ignore: cast_nullable_to_non_nullable
          : hostMessage as SentHostMessage?,
      earlyCheckIn: earlyCheckIn == const $CopyWithPlaceholder()
          ? _value.earlyCheckIn
          // ignore: cast_nullable_to_non_nullable
          : earlyCheckIn as EarlyCheckIn?,
    );
  }
}

extension $ArrivalArrangementsCopyWith on ArrivalArrangements {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfArrivalArrangements.copyWith(...)` or `instanceOfArrivalArrangements.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ArrivalArrangementsCWProxy get copyWith =>
      _$ArrivalArrangementsCWProxyImpl(this);
}
