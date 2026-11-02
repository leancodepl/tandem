// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'plan_trip_state.dart';

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
