import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late ReportsCubit reports;

  setUp(() => reports = ReportsCubit(inbox: const Inbox()));

  tearDown(() => reports.close());

  test('a trip has its own receipts, in the order of their numbers', () {
    expect(
      [for (final receipt in reports.receipts('paris')) receipt.id],
      ['R-0915-1', 'R-0915-2', 'R-0915-3', 'R-0916-1'],
    );
    expect(reports.receipts('berlin'), isEmpty);
  });

  test('a report waits until it is submitted, and only with receipts', () {
    expect(reports.waits('paris'), isTrue);
    expect(reports.waits('berlin'), isFalse);

    reports.save('paris', const ExpenseReport(submitted: 'ER-PARIS-130'));

    expect(reports.waits('paris'), isFalse);
  });
}
