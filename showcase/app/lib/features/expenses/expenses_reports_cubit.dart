import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The expense reports of the traveller's trips, for every screen of the
/// app.
final class ReportsCubit({required final Inbox inbox})
    extends Cubit<ReportsState> {
  this : super(const ReportsState({}));

  ExpenseReport report(String tripId) =>
      state.reports[tripId] ?? const ExpenseReport();

  void save(String tripId, ExpenseReport report) =>
      emit(ReportsState({...state.reports, tripId: report}));

  /// The receipts forwarded for the trip [tripId], in the order of their
  /// numbers, which follow the days.
  List<Receipt> receipts(String tripId) => [
    for (final email in inbox.emails)
      if (email case ForwardedEmail(news: final Receipt receipt)
          when email.tripId == tripId)
        receipt,
  ]..sort((a, b) => a.id.compareTo(b.id));

  /// Whether the trip [tripId] has receipts and its report is not
  /// submitted.
  bool waits(String tripId) =>
      receipts(tripId).isNotEmpty && report(tripId).submitted == null;
}

final class const ReportsState(final Map<String, ExpenseReport> reports)
    with Equatable {
  @override
  List<Object?> get props => [reports];
}

/// An expense of a report: what a receipt shows and what the company pays
/// back of it.
final class const ExpenseLine({
  required final Receipt receipt,

  /// Paid back, in whole euros: the receipt's amount or less under the
  /// policy.
  required final int claimed,
}) with Equatable {
  @override
  List<Object?> get props => [receipt, claimed];
}

/// The expenses of one trip, and its confirmation once submitted.
final class const ExpenseReport({
  final List<ExpenseLine> lines = const [],
  final String? submitted,
}) with Equatable {
  @override
  List<Object?> get props => [lines, submitted];

  int get total => lines.fold(0, (sum, line) => sum + line.claimed);

  bool claims(String receiptId) =>
      lines.any((line) => line.receipt.id == receiptId);
}
