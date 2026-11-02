// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'booking_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BookingStateCWProxy {
  BookingState marked(Set<BookingPart> marked);

  BookingState adding(bool adding);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BookingState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BookingState(...).copyWith(id: 12, name: "My name")
  /// ```
  BookingState call({Set<BookingPart> marked, bool adding});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBookingState.copyWith(...)` or call `instanceOfBookingState.copyWith.fieldName(value)` for a single field.
class _$BookingStateCWProxyImpl implements _$BookingStateCWProxy {
  const _$BookingStateCWProxyImpl(this._value);

  final BookingState _value;

  @override
  BookingState marked(Set<BookingPart> marked) => call(marked: marked);

  @override
  BookingState adding(bool adding) => call(adding: adding);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BookingState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BookingState(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BookingState call({
    Object? marked = const $CopyWithPlaceholder(),
    Object? adding = const $CopyWithPlaceholder(),
  }) {
    return BookingState(
      marked: marked == const $CopyWithPlaceholder() || marked == null
          ? _value.marked
          // ignore: cast_nullable_to_non_nullable
          : marked as Set<BookingPart>,
      adding: adding == const $CopyWithPlaceholder() || adding == null
          ? _value.adding
          // ignore: cast_nullable_to_non_nullable
          : adding as bool,
    );
  }
}

extension $BookingStateCopyWith on BookingState {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBookingState.copyWith(...)` or `instanceOfBookingState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BookingStateCWProxy get copyWith => _$BookingStateCWProxyImpl(this);
}
