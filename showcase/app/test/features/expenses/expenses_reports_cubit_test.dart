import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late ReportsCubit reports;

  setUp(() => reports = ReportsCubit(inbox: const Inbox()));

  tearDown(() => reports.close());

  test('a report snapshot owns its map and expense lines', () {
    final tripId = TripId('paris');
    final receipt = reports.receipts(tripId).first;
    final lines = [ExpenseLine(receipt: receipt, claimed: receipt.paid)];
    final report = ExpenseReport(lines: lines);
    final source = {tripId: report};
    final snapshot = ReportsState(source);

    lines.clear();
    source.clear();

    expect(snapshot.reports[tripId]?.total, receipt.paid);
    expect(snapshot.reports.clear, throwsUnsupportedError);
    expect(report.lines.clear, throwsUnsupportedError);
  });

  test('expense claims retain whole EUR precision at the report boundary', () {
    final receipt = reports.receipts(TripId('paris')).first;
    for (final claimed in [
      Money.fromIntWithCurrency(101, supportedCurrency),
      Money.fromNumWithCurrency(1, Currency.create('USD', 2)),
    ]) {
      expect(
        () => ExpenseLine(receipt: receipt, claimed: claimed),
        throwsArgumentError,
      );
    }
  });

  test('a trip has its own receipts, in the order of their numbers', () {
    expect(
      [
        for (final receipt in reports.receipts(TripId('paris')))
          receipt.id.value,
      ],
      ['R-0915-1', 'R-0915-2', 'R-0915-3', 'R-0916-1'],
    );
    expect(reports.receipts(TripId('berlin')), isEmpty);
  });

  test('a report waits until it is submitted, and only with receipts', () {
    expect(reports.waits(TripId('paris')), isTrue);
    expect(reports.waits(TripId('berlin')), isFalse);

    reports.save(
      TripId('paris'),
      ExpenseReport(submitted: BookingReference('ER-PARIS-130')),
    );

    expect(reports.waits(TripId('paris')), isFalse);
  });
}
