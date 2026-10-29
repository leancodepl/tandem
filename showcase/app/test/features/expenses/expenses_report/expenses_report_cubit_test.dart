import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_form_controller.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  final paris = demoTrips().singleWhere((trip) => trip.id == 'paris');
  late ReportsCubit reports;
  late ExpensesReportFormController form;
  late ExpensesReportCubit report;

  void open() {
    form = ExpensesReportFormController(
      receipts: reports.receipts(paris.id),
      stored: reports.report(paris.id),
    );
    report = ExpensesReportCubit(trip: paris, reports: reports, form: form);
  }

  setUp(() {
    reports = ReportsCubit(inbox: const Inbox());
    open();
  });

  tearDown(() async {
    await report.close();
    form.dispose();
  });

  List<String> tools() => [
    for (final tool in AgentListing.of(report).tools) '${tool['name']}',
  ];

  AdvancedTextFieldController<ClaimError> claim(String receiptId) => form
      .claims
      .entries
      .singleWhere((claim) => claim.key.id == receiptId)
      .value;

  Map<String, Object?> seenReceipt(String receiptId) =>
      switch (AgentListing.of(report).seen['report']) {
        {'receipts': final List<Object?> receipts} =>
          receipts.whereType<Map<String, Object?>>().singleWhere(
            (receipt) => receipt['id'] == receiptId,
          ),
        _ => const {},
      };

  test('a claim of a receipt that is not there to claim is refused', () {
    report.addExpense('R-0915-1', 58);

    for (final (receiptId, claimed) in [
      ('R-1028-1', 20),
      ('R-0915-1', 58),
      ('R-0916-1', 13),
      ('R-0916-1', 0),
    ]) {
      expect(
        () => report.addExpense(receiptId, claimed),
        throwsA(isA<ToolCallRefused>()),
        reason: '$receiptId for $claimed',
      );
    }
    expect(claim('R-0916-1').fieldValue, isEmpty);
  });

  test('a receipt taken out of the report leaves the total', () {
    report
      ..addExpense('R-0915-1', 58)
      ..addExpense('R-0916-1', 12)
      ..removeExpense('R-0915-1');

    expect(reports.report('paris').total, 12);
  });

  test('submit_report is offered once the report has an expense', () {
    expect(tools(), isNot(contains('submit_report')));

    report.addExpense('R-0916-1', 12);

    expect(tools(), contains('submit_report'));
  });

  test('a submitted report is kept and takes no more expenses', () async {
    report.addExpense('R-0916-1', 12);

    final submitted = await report.submitReport();

    expect(submitted.confirmation, 'ER-PARIS-12');
    expect(reports.report('paris').submitted, 'ER-PARIS-12');
    expect(
      tools(),
      isNot(anyOf(contains('add_expense'), contains('submit_report'))),
    );
    expect(claim('R-0916-1').value.readOnly, isTrue);
  });

  test('meals over the daily limit are refused with what is left', () {
    report.addExpense('R-0915-2', 18);

    expect(
      () => report.addExpense('R-0915-3', 71),
      throwsA(
        isA<ToolCallRefused>().having(
          (refusal) => refusal.message,
          'message',
          contains('€42 is left'),
        ),
      ),
    );
    expect(claim('R-0915-3').fieldValue, isEmpty);

    report.addExpense('R-0915-3', 42);

    expect(reports.report('paris').total, 60);
  });

  test("the traveller's claim is what the agent sees", () {
    claim('R-0916-1').textController.text = '10';

    expect(seenReceipt('R-0916-1'), containsPair('claimed', 10));
    expect(reports.report('paris').total, 10);
  });

  test('a claim with an error holds the report back', () async {
    report.addExpense('R-0915-1', 58);

    claim('R-0916-1').textController.text = '99';

    expect(claim('R-0916-1').error, const ClaimOutOfRange(12));
    expect(
      seenReceipt('R-0916-1')['problem'],
      contains('between €1 and the €12 paid'),
    );
    expect(report.ready, isFalse);
    expect(tools(), isNot(contains('submit_report')));
    expect(reports.report('paris').total, 58);
    expect(await report.submit(), isNull);
    await expectLater(report.submitReport(), throwsA(isA<ToolCallRefused>()));
  });

  test("a reopened report's meals still check each other", () async {
    report
      ..addExpense('R-0915-2', 18)
      ..addExpense('R-0915-3', 30);
    await report.close();
    form.dispose();
    open();

    claim('R-0915-3').textController.text = '50';

    for (final meal in ['R-0915-2', 'R-0915-3']) {
      expect(claim(meal).error, isA<ClaimOverPolicy>(), reason: meal);
    }

    claim('R-0915-2').textController.text = '10';

    for (final meal in ['R-0915-2', 'R-0915-3']) {
      expect(claim(meal).error, isNull, reason: meal);
    }
    expect(reports.report('paris').total, 60);
  });
}
