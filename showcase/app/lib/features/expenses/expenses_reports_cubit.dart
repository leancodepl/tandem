import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The expense reports of the traveller's trips, for every screen of the
/// app.
final class ReportsCubit({required final Inbox inbox})
    extends Cubit<ReportsState> {
  this : super(ReportsState({}));

  ExpenseReport report(TripId tripId) =>
      state.reports[tripId] ?? ExpenseReport();

  void save(TripId tripId, ExpenseReport report) =>
      emit(ReportsState({...state.reports, tripId: report}));

  /// The receipts forwarded for the trip [tripId], in the order of their
  /// numbers, which follow the days.
  List<Receipt> receipts(TripId tripId) => [
    for (final email in inbox.emails)
      if (email case ForwardedEmail(news: final Receipt receipt)
          when email.tripId == tripId)
        receipt,
  ]..sort((a, b) => a.id.value.compareTo(b.id.value));

  /// Whether the trip [tripId] has receipts and its report is not
  /// submitted.
  bool waits(TripId tripId) =>
      receipts(tripId).isNotEmpty && report(tripId).submitted == null;
}

final class ReportsState(Map<TripId, ExpenseReport> reports) with Equatable {
  final Map<TripId, ExpenseReport> reports = Map.unmodifiable(reports);
  @override
  List<Object?> get props => [reports];
}

/// An expense of a report: what a receipt shows and what the company pays
/// back of it.
final class ExpenseLine({
  required final Receipt receipt,

  /// Paid back, in whole euros: the receipt's amount or less under the
  /// policy.
  required final Money claimed,
}) with Equatable {
  this {
    requireSupportedWholeMoney(claimed, 'claimed');
    if (claimed <= wholeMoney(0) || claimed > receipt.paid) {
      throw ArgumentError.value(
        claimed,
        'claimed',
        'Must be positive and no more than the receipt amount',
      );
    }
  }

  @override
  List<Object?> get props => [receipt, claimed];
}

/// The expenses of one trip, and its confirmation once submitted.
final class ExpenseReport({
  List<ExpenseLine> lines = const [],
  final BookingReference? submitted,
}) with Equatable {
  final List<ExpenseLine> lines = List.unmodifiable(lines);

  @override
  List<Object?> get props => [lines, submitted];

  Money get total =>
      lines.fold(wholeMoney(0), (sum, line) => sum + line.claimed);

  bool claims(ReceiptId receiptId) =>
      lines.any((line) => line.receipt.id == receiptId);
}
