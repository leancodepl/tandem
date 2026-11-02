import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/expenses/expense_report.dart';
import 'package:waypoint/features/expenses/expenses_report/claim_error.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_form_controller.dart';
import 'package:waypoint/features/expenses/expenses_report/receipt_claim_field.dart';
import 'package:waypoint/features/expenses/expenses_report/report_submission.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  final paris = demoTrips().singleWhere((trip) => trip.id == TripId('paris'));
  late ReportsCubit reports;
  late ExpensesReportFormController form;
  late ExpensesReportCubit report;

  void open() {
    form = ExpensesReportFormController(
      receipts: reports.receipts(paris.id),
      stored: reports.report(paris.id),
      inputs: reports.draftInputs(paris.id),
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

  AdvancedTextFieldController<ClaimError> claim(String receiptId) =>
      switch (form.claims[ReceiptId(receiptId)]) {
        ReceiptClaimField(:final field) => field,
        null => fail('No field for receipt $receiptId.'),
      };

  Map<String, Object?> seenReceipt(String receiptId) =>
      switch (AgentListing.of(report).seen['report']) {
        {'receipts': final List<Object?> receipts} =>
          receipts.whereType<Map<String, Object?>>().singleWhere(
            (receipt) => receipt['id'] == receiptId,
          ),
        _ => const {},
      };

  test('a saved claim follows the receipt id when its details change', () {
    final receipt = reports.receipts(paris.id).first;
    final corrected = Receipt(
      id: receipt.id,
      merchant: 'Corrected merchant name',
      category: receipt.category,
      day: receipt.day,
      paid: receipt.paid,
    );
    final reopened = ExpensesReportFormController(
      receipts: [corrected],
      stored: ExpenseReport(
        lines: [ExpenseLine(receipt: receipt, claimed: receipt.paid)],
      ),
    );
    addTearDown(reopened.dispose);

    expect(reopened.isClaimed(receipt.id), isTrue);
    expect(reopened.total, receipt.paid);
    expect(reopened.lines.single.receipt, corrected);
  });

  test('a corrected receipt revalidates its saved claim before edits', () {
    final receipts = reports.receipts(paris.id);
    final taxi = receipts.first;
    final transport = receipts.last;
    final stored = ExpenseReport(
      lines: [ExpenseLine(receipt: taxi, claimed: taxi.paid)],
    );
    reports.saveDraft(
      paris.id,
      inputs: {taxi.id: '${taxi.paid.toInt()}'},
      validated: stored,
    );
    final corrected = Receipt(
      id: taxi.id,
      merchant: taxi.merchant,
      category: taxi.category,
      day: taxi.day,
      paid: wholeMoney(40),
    );
    final reopenedForm = ExpensesReportFormController(
      receipts: [corrected, transport],
      stored: stored,
    );
    final reopenedReport = ExpensesReportCubit(
      trip: paris,
      reports: reports,
      form: reopenedForm,
    );
    addTearDown(() async {
      await reopenedReport.close();
      reopenedForm.dispose();
    });

    expect(
      reopenedForm.claims[taxi.id]?.field.error,
      ClaimOutOfRange(wholeMoney(40)),
    );
    reopenedReport.addExpense(transport.id.value, transport.paid.toInt());

    expect(reopenedReport.ready, isFalse);
    expect(reports.report(paris.id), stored);
    expect(reopenedReport.report.receipts.first.problem, contains('€40 paid'));
  });

  test('the meal limit groups UTC and local receipts by calendar day', () {
    final first = Receipt(
      id: ReceiptId('meal-local'),
      merchant: 'Lunch',
      category: .meal,
      day: DateTime(2026, 9, 15),
      paid: wholeMoney(40),
    );
    final second = Receipt(
      id: ReceiptId('meal-utc'),
      merchant: 'Dinner',
      category: .meal,
      day: DateTime.utc(2026, 9, 15),
      paid: wholeMoney(40),
    );
    final mixed = ExpensesReportFormController(
      receipts: [first, second],
      stored: ExpenseReport(
        lines: [ExpenseLine(receipt: first, claimed: first.paid)],
      ),
    );
    addTearDown(mixed.dispose);

    expect(mixed.claimError(second, '40'), isA<ClaimOverPolicy>());
  });

  test('a claim of a receipt that is not there to claim is refused', () {
    report.addExpense('R-0915-1', 58);

    for (final (receiptId, claimed) in [
      ('R-1028-1', 20),
      ('  ', 20),
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

    expect(reports.report(TripId('paris')).total, wholeMoney(12));
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
    expect(
      reports.report(TripId('paris')).submitted,
      BookingReference('ER-PARIS-12'),
    );
    expect(
      tools(),
      isNot(anyOf(contains('add_expense'), contains('submit_report'))),
    );
    expect(claim('R-0916-1').value.readOnly, isTrue);
  });

  test(
    'a submission stays locked and completes after the page is reopened',
    () async {
      report.addExpense('R-0916-1', 12);
      final submission = report.submitReport();
      await Future<void>.delayed(Duration.zero);
      await report.close();
      form.dispose();
      open();

      expect(report.state.submitting, isTrue);
      expect(claim('R-0916-1').value.readOnly, isTrue);
      await expectLater(report.submitReport(), throwsA(isA<ToolCallRefused>()));
      final submitted = await submission;
      await Future<void>.delayed(Duration.zero);

      expect(report.report.submitted, submitted.confirmation);
      expect(claim('R-0916-1').fieldValue, '12');
      expect(
        () => report.removeExpense('R-0916-1'),
        throwsA(isA<ToolCallRefused>()),
      );
      claim('R-0916-1').textController.text = '10';
      expect(reports.report(paris.id).submitted?.value, submitted.confirmation);
      expect(reports.report(paris.id).total, wholeMoney(12));
    },
  );

  test('removing an unknown receipt is refused', () {
    expect(
      () => report.removeExpense('unknown'),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test(
    'two manual submissions produce one report without a UI exception',
    () async {
      report.addExpense('R-0916-1', 12);
      final otherForm = ExpensesReportFormController(
        receipts: reports.receipts(paris.id),
        stored: reports.report(paris.id),
        inputs: reports.draftInputs(paris.id),
      );
      final other = ExpensesReportCubit(
        trip: paris,
        reports: reports,
        form: otherForm,
      );
      addTearDown(() async {
        await other.close();
        otherForm.dispose();
      });

      final submitted = await Future.wait([report.submit(), other.submit()]);

      expect(submitted.whereType<Submitted>(), hasLength(1));
      expect(reports.report(paris.id).submitted, isNotNull);
    },
  );

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

    expect(reports.report(TripId('paris')).total, wholeMoney(60));
  });

  test("the traveller's claim is what the agent sees", () {
    claim('R-0916-1').textController.text = '10';

    expect(seenReceipt('R-0916-1'), containsPair('claimed', 10));
    expect(reports.report(TripId('paris')).total, wholeMoney(10));
  });

  test('a claim with an error holds the report back', () async {
    report.addExpense('R-0915-1', 58);

    claim('R-0916-1').textController.text = '99';

    expect(claim('R-0916-1').error, ClaimOutOfRange(wholeMoney(12)));
    expect(
      seenReceipt('R-0916-1')['problem'],
      contains('between €1 and the €12 paid'),
    );
    expect(report.ready, isFalse);
    expect(tools(), isNot(contains('submit_report')));
    expect(reports.report(TripId('paris')).total, wholeMoney(58));
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
    expect(reports.report(TripId('paris')).total, wholeMoney(60));
  });
}
