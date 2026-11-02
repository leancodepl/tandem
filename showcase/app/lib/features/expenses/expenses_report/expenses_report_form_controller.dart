import 'package:advanced_forms/advanced_forms.dart';
import 'package:waypoint/features/expenses/expense_report.dart';
import 'package:waypoint/features/expenses/expenses_report/claim_error.dart';
import 'package:waypoint/features/expenses/expenses_report/receipt_claim_field.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The expense report form: what is claimed of each of the trip's
/// [receipts], starting from the report the store holds.
final class ExpensesReportFormController({
  required List<Receipt> receipts,
  required ExpenseReport stored,
}) extends AdvancedFormController {
  this : super(validationMode: .onUserInteraction) {
    // Seeded before registerFields: touched, but not validated.
    restore(stored);
    registerFields([for (final claim in claims.values) claim.field]);
    for (final ReceiptClaimField(:receipt, :field) in claims.values) {
      if (receipt.category == .meal) {
        field.subscribeToFields([
          for (final other in _otherMealsOf(receipt)) other.field,
        ]);
      }
    }
    revalidateSync();
    if (stored.submitted != null) markReadOnly();
  }

  final List<Receipt> receipts = List.unmodifiable(receipts);

  /// The whole euros claimed of each receipt, in receipt order. Empty
  /// means the receipt is not in the report.
  late final Map<ReceiptId, ReceiptClaimField> claims = Map.unmodifiable({
    for (final receipt in receipts)
      receipt.id: ReceiptClaimField(
        receipt: receipt,
        field: AdvancedTextFieldController(
          validator: (text) => claimError(receipt, text),
        ),
      ),
  });

  void restore(ExpenseReport report) {
    final saved = {
      for (final line in report.lines) line.receipt.id: line.claimed,
    };
    for (final MapEntry(key: id, value: claim) in claims.entries) {
      final amount = saved[id];
      final text = amount == null ? '' : '${amount.toInt()}';
      if (claim.field.fieldValue != text) {
        claim.field.setValue(text, force: true);
      }
    }
    revalidateSync();
  }

  /// What is wrong with claiming [text] of [receipt], or null. An empty
  /// claim is not wrong: the receipt is just not in the report.
  ClaimError? claimError(Receipt receipt, String text) {
    if (text.trim().isEmpty) return null;
    final claimed = _inRange(receipt, text);
    if (claimed == null) return ClaimOutOfRange(receipt.paid);
    if (receipt.category != .meal) return null;

    var otherMeals = wholeMoney(0);
    for (final ReceiptClaimField(receipt: meal, :field) in _otherMealsOf(
      receipt,
    )) {
      otherMeals += _inRange(meal, field.fieldValue) ?? wholeMoney(0);
    }
    final breach = Policy.checkMeals(
      claimed: claimed,
      claimedThatDay: otherMeals > Policy.mealsPerDay
          ? Policy.mealsPerDay
          : otherMeals,
    );
    return breach == null ? null : ClaimOverPolicy(breach);
  }

  /// The claims that are in the report, in receipt order.
  List<ExpenseLine> get lines => [
    for (final ReceiptClaimField(:receipt, :field) in claims.values)
      if (_inRange(receipt, field.fieldValue) case final claimed?)
        ExpenseLine(receipt: receipt, claimed: claimed),
  ];

  /// Paid back in all, in euros.
  Money get total =>
      lines.fold(wholeMoney(0), (sum, line) => sum + line.claimed);

  /// Whether the receipt [receiptId] is in the report.
  bool isClaimed(ReceiptId receiptId) => switch (claims[receiptId]) {
    ReceiptClaimField(:final field) => field.fieldValue.trim().isNotEmpty,
    null => false,
  };

  Iterable<ReceiptClaimField> _otherMealsOf(Receipt receipt) => [
    for (final claim in claims.values)
      if (claim.receipt.id != receipt.id &&
          claim.receipt.category == .meal &&
          calendarDaysBetween(claim.receipt.day, receipt.day) == 0)
        claim,
  ];

  /// The euros claimed in [text] when they lie between 1 and what was paid
  /// for [receipt].
  static Money? _inRange(Receipt receipt, String text) =>
      switch (int.tryParse(text.trim())) {
        final claimed? when claimed > 0 && claimed <= receipt.paid.toInt() =>
          wholeMoney(claimed),
        _ => null,
      };
}
