import 'package:equatable/equatable.dart';
import 'package:waypoint/features/expenses/expense_report.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class ReportsState(
  Map<TripId, ExpenseReport> reports, {
  Set<TripId> submitting = const {},
  Map<TripId, Map<ReceiptId, String>> drafts = const {},
}) with Equatable {
  final Map<TripId, ExpenseReport> reports = Map.unmodifiable(reports);
  final Set<TripId> submitting = Set.unmodifiable(submitting);
  final Map<TripId, Map<ReceiptId, String>> drafts = Map.unmodifiable({
    for (final entry in drafts.entries)
      entry.key: Map<ReceiptId, String>.unmodifiable(entry.value),
  });

  @override
  List<Object?> get props => [reports, submitting, drafts];
}
