import 'package:waypoint_travel/waypoint_travel.dart';

final class const ReportSummary({
  required final String trip,
  required final List<ReceiptSummary> receipts,

  /// Paid back in all, in euros.
  required final int total,

  /// The confirmation once the report is submitted.
  final String? submitted,
});

final class const ReceiptSummary({
  required final String id,
  required final String merchant,
  required final ExpenseCategory category,
  required final String day,
  required final int paid,

  /// Paid back of it, or null while it is not in the report.
  final int? claimed,

  /// Why the screen marks the claim as wrong, such as more than was paid,
  /// or null while it is right. The report cannot be submitted while a
  /// claim has a problem.
  final String? problem,
});
