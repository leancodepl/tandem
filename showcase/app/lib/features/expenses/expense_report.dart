import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class ExpenseReport({
  List<ExpenseLine> lines = const [],
  final BookingReference? submitted,
}) with Equatable {
  this {
    final receiptIds = <ReceiptId>{};
    for (final line in lines) {
      if (receiptIds.add(line.receipt.id)) continue;
      throw ArgumentError.value(
        line.receipt.id,
        'lines',
        'A receipt appears only once in a report.',
      );
    }
  }

  final List<ExpenseLine> lines = List.unmodifiable(lines);

  @override
  List<Object?> get props => [lines, submitted];

  Money get total =>
      lines.fold(wholeMoney(0), (sum, line) => sum + line.claimed);

  bool claims(ReceiptId receiptId) =>
      lines.any((line) => line.receipt.id == receiptId);
}

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

final class const ReportLocked(final String reason) implements Exception;
