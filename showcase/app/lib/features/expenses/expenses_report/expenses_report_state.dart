import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'expenses_report_state.g.dart';

/// What the expense report shows besides its claims.
@CopyWith()
final class const ExpensesReportState._({
  /// The confirmation once the report is submitted.
  final BookingReference? submitted,

  /// The report is being submitted.
  final bool submitting = false,

  /// The receipts whose claim the agent filled in and the traveller has
  /// not changed.
  final Set<ReceiptId> marked = const {},
}) with Equatable {
  factory({
    BookingReference? submitted,
    bool submitting = false,
    Set<ReceiptId> marked = const {},
  }) => ExpensesReportState._(
    submitted: submitted,
    submitting: submitting,
    marked: Set.unmodifiable(marked),
  );

  @override
  List<Object?> get props => [submitted, submitting, marked];
}
