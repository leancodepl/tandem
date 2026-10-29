import 'package:advanced_forms/advanced_forms.dart';
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
  }

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
      for (final MapEntry(key: receipt, value: claim) in form.claims.entries)
        ReceiptSummary(
          id: receipt.id,
          merchant: receipt.merchant,
          category: receipt.category,
          day: forAgent(receipt.day, withTime: false),
          paid: receipt.paid,
          claimed: int.tryParse(claim.fieldValue.trim()),
          problem: claim.error?.forAgent,
        ),
    ],
    total: form.total,
    submitted: state.submitted,
  );

  /// The company's rules for expenses.
  String get policy => Policy.expensesForAgent;

  /// Adds the receipt [receiptId] to the report, paying back [claimed] whole
  /// euros of it: what was paid, or less where the policy limits it.
  void addExpense(String receiptId, int claimed) {
    final entry = _claimOf(receiptId);
    if (entry == null) {
      _refuse('There is no receipt $receiptId on this trip.');
    }
    if (form.isClaimed(receiptId)) {
      _refuse('$receiptId is in the report already.');
    }
    final MapEntry(key: receipt, value: claim) = entry;
    if (form.claimError(receipt, '$claimed') case final error?) {
      _refuse('${error.forAgent}.');
    }
    claim.setValue('$claimed');
    emit(state.copyWith(marked: {...state.marked, receiptId}));
  }

  /// Takes the receipt [receiptId] out of the report.
  void removeExpense(String receiptId) {
    _claimOf(receiptId)?.value.setValue('');
    unmark(receiptId);
  }

  /// Whether the report can be submitted: open, with an expense, and no
  /// claim wrong.
  bool get ready => _open && form.lines.isNotEmpty && form.value.canSubmit;

  /// Submits the report exactly as it is on the screen, to be paid back.
  /// Returns its confirmation, to tell the traveller.
  Future<Submitted> submitReport() async =>
      await submit() ?? _refuse('Fix the claims the screen marks first.');

  /// Submits the report once it checks out; null if it does not.
  Future<Submitted?> submit() async {
    if (!ready) return null;

    final lines = form.lines;
    final total = form.total;
    _log.info('Submitting the report of trip ${trip.id} for $total €');
    emit(state.copyWith(submitting: true));
    form.markReadOnly();
    if (!await form.validate()) {
      if (!isClosed) {
        emit(state.copyWith(submitting: false));
        form.unmarkReadOnly();
      }
      return null;
    }

    // Waypoint's showcase submits nothing for real.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final confirmation = 'ER-${trip.id.toUpperCase()}-$total';
    reports.save(trip.id, ExpenseReport(lines: lines, submitted: confirmation));
    _log.info('Submitted the report of trip ${trip.id} as $confirmation');
    if (!isClosed) {
      emit(state.copyWith(submitted: confirmation, submitting: false));
    }
    return Submitted(confirmation: confirmation, total: total);
  }

  /// The traveller changed the claim of the receipt [receiptId] by hand.
  void unmark(String receiptId) =>
      emit(state.copyWith(marked: {...state.marked}..remove(receiptId)));

  @override
  Future<void> close() {
    _saves.removeListener(_save);
    return super.close();
  }

  bool get _open => state.submitted == null && !state.submitting;

  MapEntry<Receipt, AdvancedTextFieldController<ClaimError>>? _claimOf(
    String receiptId,
  ) => form.claims.entries
      .where((claim) => claim.key.id == receiptId)
      .firstOrNull;

  /// Keeps the report in the store while it is open and every claim is
  /// right, so the store only ever holds a report that could be submitted.
  void _save() {
    if (_open && form.value.canSubmit) {
      reports.save(trip.id, ExpenseReport(lines: form.lines));
    }
  }

  Never _refuse(String reason) {
    _log.warning('Refused: $reason');
    throw ToolCallRefused(reason);
  }
}

/// What the expense report shows besides its claims.
@CopyWith()
final class const ExpensesReportState({
  /// The confirmation once the report is submitted.
  final String? submitted,

  /// The report is being submitted.
  final bool submitting = false,

  /// The receipts whose claim the agent filled in and the traveller has
  /// not changed.
  final Set<String> marked = const {},
}) with Equatable {
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
