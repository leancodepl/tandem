import 'package:equatable/equatable.dart';
import 'package:waypoint/features/expenses/expense_report.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class ReportsState(
  Map<TripId, ExpenseReport> reports, {
  Set<TripId> submitting = const {},
}) with Equatable {
  final Map<TripId, ExpenseReport> reports = Map.unmodifiable(reports);
  final Set<TripId> submitting = Set.unmodifiable(submitting);

  @override
  List<Object?> get props => [reports, submitting];
}
