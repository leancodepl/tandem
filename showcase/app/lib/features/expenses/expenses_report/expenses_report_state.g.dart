// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_type_name_in_constructor, use_primary_constructors

part of 'expenses_report_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ExpensesReportStateCWProxy {
  ExpensesReportState submitted(BookingReference? submitted);

  ExpensesReportState submitting(bool submitting);

  ExpensesReportState marked(Set<ReceiptId> marked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ExpensesReportState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ExpensesReportState(...).copyWith(id: 12, name: "My name")
  /// ```
  ExpensesReportState call({
    BookingReference? submitted,
    bool submitting,
    Set<ReceiptId> marked,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfExpensesReportState.copyWith(...)` or call `instanceOfExpensesReportState.copyWith.fieldName(value)` for a single field.
class _$ExpensesReportStateCWProxyImpl implements _$ExpensesReportStateCWProxy {
  const _$ExpensesReportStateCWProxyImpl(this._value);

  final ExpensesReportState _value;

  @override
  ExpensesReportState submitted(BookingReference? submitted) =>
      call(submitted: submitted);

  @override
  ExpensesReportState submitting(bool submitting) =>
      call(submitting: submitting);

  @override
  ExpensesReportState marked(Set<ReceiptId> marked) => call(marked: marked);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ExpensesReportState(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ExpensesReportState(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ExpensesReportState call({
    Object? submitted = const $CopyWithPlaceholder(),
    Object? submitting = const $CopyWithPlaceholder(),
    Object? marked = const $CopyWithPlaceholder(),
  }) {
    return ExpensesReportState(
      submitted: submitted == const $CopyWithPlaceholder()
          ? _value.submitted
          // ignore: cast_nullable_to_non_nullable
          : submitted as BookingReference?,
      submitting:
          submitting == const $CopyWithPlaceholder() || submitting == null
          ? _value.submitting
          // ignore: cast_nullable_to_non_nullable
          : submitting as bool,
      marked: marked == const $CopyWithPlaceholder() || marked == null
          ? _value.marked
          // ignore: cast_nullable_to_non_nullable
          : marked as Set<ReceiptId>,
    );
  }
}

extension $ExpensesReportStateCopyWith on ExpensesReportState {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfExpensesReportState.copyWith(...)` or `instanceOfExpensesReportState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ExpensesReportStateCWProxy get copyWith =>
      _$ExpensesReportStateCWProxyImpl(this);
}
