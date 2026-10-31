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

  test('a submitted report cannot be overwritten by an old draft', () async {
    final tripId = TripId('paris');
    final receipt = reports.receipts(tripId).first;
    final draft = ExpenseReport(
      lines: [ExpenseLine(receipt: receipt, claimed: receipt.paid)],
    );
    final submitted = await reports.submit(tripId, draft);

    expect(reports.saveDraft(tripId, ExpenseReport()), isFalse);
    expect(reports.report(tripId), submitted);
    await expectLater(
      reports.submit(tripId, draft),
      throwsA(isA<ReportLocked>()),
    );
  });

  test('a receipt contributes to a report only once', () {
    final receipt = reports.receipts(TripId('paris')).first;

    expect(
      () => ExpenseReport(
        lines: [
          ExpenseLine(receipt: receipt, claimed: wholeMoney(10)),
          ExpenseLine(receipt: receipt, claimed: wholeMoney(20)),
        ],
      ),
      throwsArgumentError,
    );
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

  test(
    'a report waits until it is submitted, and only with receipts',
    () async {
      expect(reports.waits(TripId('paris')), isTrue);
      expect(reports.waits(TripId('berlin')), isFalse);

      final tripId = TripId('paris');
      final receipt = reports.receipts(tripId).first;
      await reports.submit(
        tripId,
        ExpenseReport(
          lines: [ExpenseLine(receipt: receipt, claimed: receipt.paid)],
        ),
      );

      expect(reports.waits(TripId('paris')), isFalse);
    },
  );
}
