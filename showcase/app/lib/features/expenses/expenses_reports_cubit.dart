import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/features/expenses/expense_report.dart';
import 'package:waypoint/features/expenses/expenses_reports_state.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class ReportsCubit({required final Inbox inbox})
    extends Cubit<ReportsState> {
  this : super(ReportsState({}));

  ExpenseReport report(TripId tripId) =>
      state.reports[tripId] ?? ExpenseReport();

  Map<ReceiptId, String> draftInputs(TripId tripId) =>
      state.drafts[tripId] ?? const {};

  bool isSubmitting(TripId tripId) => state.submitting.contains(tripId);

  bool isEditable(TripId tripId) =>
      report(tripId).submitted == null && !isSubmitting(tripId);

  bool saveDraft(
    TripId tripId, {
    required Map<ReceiptId, String> inputs,
    ExpenseReport? validated,
  }) {
    if (validated?.submitted != null) {
      throw ArgumentError.value(
        validated,
        'validated',
        'A draft has no submission reference.',
      );
    }
    if (isEditable(tripId)) {
      emit(
        ReportsState(
          {...state.reports, tripId: ?validated},
          submitting: state.submitting,
          drafts: {...state.drafts, tripId: inputs},
        ),
      );
      return true;
    }
    return false;
  }

  Future<ExpenseReport> submit(TripId tripId, ExpenseReport draft) async {
    if (isSubmitting(tripId)) {
      throw const ReportLocked('This report is being submitted.');
    }
    if (report(tripId).submitted != null) {
      throw const ReportLocked('This report has already been submitted.');
    }
    if (draft.submitted != null || draft.lines.isEmpty) {
      throw ArgumentError.value(draft, 'draft', 'Submit a nonempty draft.');
    }
    emit(
      ReportsState(
        {...state.reports, tripId: draft},
        submitting: {...state.submitting, tripId},
        drafts: state.drafts,
      ),
    );
    try {
      // Waypoint's showcase submits nothing for real.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final confirmed = ExpenseReport(
        lines: draft.lines,
        submitted: BookingReference(
          'ER-${tripId.value.toUpperCase()}-${draft.total.toInt()}',
        ),
      );
      if (!isClosed) {
        emit(
          ReportsState(
            {...state.reports, tripId: confirmed},
            submitting: {...state.submitting}..remove(tripId),
            drafts: {...state.drafts}..remove(tripId),
          ),
        );
      }
      return confirmed;
    } finally {
      if (!isClosed && isSubmitting(tripId)) {
        emit(
          ReportsState(
            state.reports,
            submitting: {...state.submitting}..remove(tripId),
            drafts: state.drafts,
          ),
        );
      }
    }
  }

  /// Receipt numbers follow their days.
  List<Receipt> receipts(TripId tripId) => [
    for (final email in inbox.emails)
      if (email case ForwardedEmail(news: final Receipt receipt)
          when email.tripId == tripId)
        receipt,
  ]..sort((a, b) => a.id.value.compareTo(b.id.value));

  bool waits(TripId tripId) =>
      receipts(tripId).isNotEmpty && report(tripId).submitted == null;
}
