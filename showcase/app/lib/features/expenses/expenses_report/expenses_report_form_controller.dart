import 'dart:math';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The expense report form: what is claimed of each of the trip's
/// [receipts], starting from the report the store holds.
final class ExpensesReportFormController({
  required final List<Receipt> receipts,
  required ExpenseReport stored,
}) extends AdvancedFormController {
  this : super(validationMode: .onUserInteraction) {
    // Seeded before registerFields: touched, but not validated.
    for (final line in stored.lines) {
      claims[line.receipt]?.setValue('${line.claimed}');
    }
    registerFields([...claims.values]);
    for (final MapEntry(key: receipt, value: claim) in claims.entries) {
      if (receipt.category == .meal) {
        claim.subscribeToFields([
          for (final (_, other) in _otherMealsOf(receipt)) other,
        ]);
      }
    }
    if (stored.submitted != null) markReadOnly();
  }

  /// The whole euros claimed of each receipt, in receipt order. Empty
  /// means the receipt is not in the report.
  late final Map<Receipt, AdvancedTextFieldController<ClaimError>> claims = {
    for (final receipt in receipts)
      receipt: AdvancedTextFieldController(
        validator: (text) => claimError(receipt, text),
      ),
  };

  /// What is wrong with claiming [text] of [receipt], or null. An empty
  /// claim is not wrong: the receipt is just not in the report.
  ClaimError? claimError(Receipt receipt, String text) {
    if (text.trim().isEmpty) return null;
    final claimed = _inRange(receipt, text);
    if (claimed == null) return ClaimOutOfRange(receipt.paid);
    if (receipt.category != .meal) return null;

    var otherMeals = 0;
    for (final (meal, claim) in _otherMealsOf(receipt)) {
      otherMeals += _inRange(meal, claim.fieldValue) ?? 0;
    }
    final breach = Policy.checkMeals(
      claimed: claimed,
      claimedThatDay: min(Policy.mealsPerDay, otherMeals),
    );
    return breach == null ? null : ClaimOverPolicy(breach);
  }

  /// The claims that are in the report, in receipt order.
  List<ExpenseLine> get lines => [
    for (final MapEntry(key: receipt, value: claim) in claims.entries)
      if (int.tryParse(claim.fieldValue.trim()) case final claimed?)
        ExpenseLine(receipt: receipt, claimed: claimed),
  ];

  /// Paid back in all, in euros.
  int get total => lines.fold(0, (sum, line) => sum + line.claimed);

  /// Whether the receipt [receiptId] is in the report.
  bool isClaimed(String receiptId) => claims.entries.any(
    (claim) =>
        claim.key.id == receiptId && claim.value.fieldValue.trim().isNotEmpty,
  );

  Iterable<(Receipt, AdvancedTextFieldController<ClaimError>)> _otherMealsOf(
    Receipt receipt,
  ) => [
    for (final MapEntry(key: other, value: claim) in claims.entries)
      if (other != receipt &&
          other.category == .meal &&
          dateOnly(other.day) == dateOnly(receipt.day))
        (other, claim),
  ];

  /// The euros claimed in [text] when they lie between 1 and what was paid
  /// for [receipt].
  static int? _inRange(Receipt receipt, String text) =>
      switch (int.tryParse(text.trim())) {
        final claimed? when claimed > 0 && claimed <= receipt.paid => claimed,
        _ => null,
      };
}

/// Why a claim of the expense report is wrong.
sealed class const ClaimError() with Equatable {
  /// The error in English, for the agent.
  String get forAgent;
}

/// The claim is not a whole number of euros between 1 and the [paid]
/// amount of its receipt.
final class const ClaimOutOfRange(final int paid) extends ClaimError {
  @override
  List<Object?> get props => [paid];

  @override
  String get forAgent => 'Claim between €1 and the €$paid paid';
}

/// The claim breaks the company's policy.
final class const ClaimOverPolicy(final PolicyBreach breach)
    extends ClaimError {
  @override
  List<Object?> get props => [breach];

  @override
  String get forAgent => breach.forAgent;
}
