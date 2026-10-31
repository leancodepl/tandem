import 'dart:async';

import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/common/tandem/form_changes.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_form_controller.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'expenses_report_cubit.g.dart';

final _log = Logger('Expenses');

/// The expense report of a past trip, which the agent fills in from the
/// trip's receipts. Submitting it waits for the traveller's approval.
@TandemAgent()
class ExpensesReportCubit({
  required final Trip trip,

  /// Where the report is kept, also once the screen is closed.
  required final ReportsCubit reports,
  @override required final ExpensesReportFormController form,
}) extends Cubit<ExpensesReportState>
    with _$ExpensesReportCubit, FormChanges<ExpensesReportState> {
  this
    : super(ExpensesReportState(submitted: reports.report(trip.id).submitted)) {
    _saves.addListener(_save);
    _reportChanges = reports.stream.listen((_) => _syncSubmission());
    _syncSubmission();
  }

  late final StreamSubscription<ReportsState> _reportChanges;
  var _validating = false;

  // Status too: a meal fixed from its pair turns valid after the values
  // notify.
  late final _saves = Listenable.merge([
    form.onValuesChanged,
    form.onStatusChanged,
  ]);

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(report),
    .sees(policy),
    if (_open) ...[.calls(addExpense), .calls(removeExpense)],
    if (ready) .callsWithApproval(submitReport),
  ];

  List<Receipt> get receipts => form.receipts;

  /// The report as the traveller sees it: every receipt of the trip and
  /// what of it is paid back.
  ReportSummary get report => ReportSummary(
    trip:
        '${trip.city}, '
        '${dayRangeForAgent(trip.booked.outbound.departs, trip.booked.homebound.departs)}',
    receipts: [
      for (final ReceiptClaimField(:receipt, :field) in form.claims.values)
        ReceiptSummary(
          id: receipt.id.value,
          merchant: receipt.merchant,
          category: receipt.category,
          day: forAgent(receipt.day, withTime: false),
          paid: receipt.paid.toInt(),
          claimed: int.tryParse(field.fieldValue.trim()),
          problem: field.error?.forAgent,
        ),
    ],
    total: form.total.toInt(),
    submitted: state.submitted?.value,
  );

  /// The company's rules for expenses.
  String get policy => Policy.expensesForAgent;

  /// Adds the receipt [receiptId] to the report, paying back [claimed] whole
  /// euros of it: what was paid, or less where the policy limits it.
  void addExpense(String receiptId, int claimed) {
    _requireOpen();
    final entry = _claim(receiptId);
    final id = entry.receipt.id;
    if (form.isClaimed(id)) {
      _refuse('$receiptId is in the report already.');
    }
    final ReceiptClaimField(:receipt, field: claim) = entry;
    if (form.claimError(receipt, '$claimed') case final error?) {
      _refuse('${error.forAgent}.');
    }
    claim.setValue('$claimed');
    emit(state.copyWith(marked: {...state.marked, id}));
  }

  /// Takes the receipt [receiptId] out of the report.
  void removeExpense(String receiptId) {
    _requireOpen();
    final entry = _claim(receiptId);
    entry.field.setValue('');
    unmark(entry.receipt.id);
  }

  /// Whether the report can be submitted: open, with an expense, and no
  /// claim wrong.
  bool get ready => _open && form.lines.isNotEmpty && form.value.canSubmit;

  /// Submits the report exactly as it is on the screen, to be paid back.
  /// Returns its confirmation, to tell the traveller.
  Future<Submitted> submitReport() async {
    _requireOpen();
    final submitted = await submit();
    if (submitted != null) return submitted;
    _requireOpen();
    _refuse('Fix the claims the screen marks first.');
  }

  /// Submits the report once it checks out; null if it does not.
  Future<Submitted?> submit() async {
    if (!ready) return null;

    final draft = ExpenseReport(lines: form.lines);
    _validating = true;
    _syncSubmission();
    try {
      if (!await form.validate()) return null;
      final submission = reports.submit(trip.id, draft);
      _validating = false;
      if (!isClosed) _syncSubmission();
      final confirmed = await submission;
      final confirmation = confirmed.submitted;
      if (confirmation == null) {
        throw StateError('The report has no submission reference.');
      }
      _log.info('Submitted the report of trip ${trip.id} as $confirmation');
      return Submitted(
        confirmation: confirmation.value,
        total: confirmed.total.toInt(),
      );
    } on ReportLocked {
      return null;
    } finally {
      _validating = false;
      if (!isClosed) _syncSubmission();
    }
  }

  /// The traveller changed the claim of the receipt [receiptId] by hand.
  void unmark(ReceiptId receiptId) =>
      emit(state.copyWith(marked: {...state.marked}..remove(receiptId)));

  @override
  Future<void> close() async {
    _saves.removeListener(_save);
    await _reportChanges.cancel();
    await super.close();
  }

  bool get _open => reports.isEditable(trip.id) && !_validating;

  void _syncSubmission() {
    final stored = reports.report(trip.id);
    final submitting = _validating || reports.isSubmitting(trip.id);
    final locked = submitting || stored.submitted != null;
    if (reports.isSubmitting(trip.id) || stored.submitted != null) {
      form.restore(stored);
    }
    if (locked) {
      form.markReadOnly();
    } else {
      form.unmarkReadOnly();
    }
    emit(state.copyWith(submitted: stored.submitted, submitting: submitting));
  }

  ReceiptClaimField _claim(String receiptId) {
    final id = ReceiptId.tryParse(receiptId);
    if (id == null) _refuse('The receipt id must not be empty.');
    return form.claims[id] ??
        _refuse('There is no receipt $receiptId on this trip.');
  }

  void _requireOpen() {
    if (_validating || reports.isSubmitting(trip.id)) {
      _refuse('This report is being submitted.');
    }
    if (reports.report(trip.id).submitted != null) {
      _refuse('This report has already been submitted.');
    }
  }

  /// Keeps the report in the store while it is open and every claim is
  /// right, so the store only ever holds a report that could be submitted.
  void _save() {
    if (_open && form.value.canSubmit) {
      reports.saveDraft(trip.id, ExpenseReport(lines: form.lines));
    }
  }

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

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

/// What submit_report submitted.
final class const Submitted({
  required final String confirmation,
  required final int total,
});
