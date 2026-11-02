import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/app.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_cubit.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_page.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  testWidgets('receipts are added only after an explicit request', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('add_expense', {
          'receiptId': 'R-0916-1',
          'claimed': 12,
        }),
      ],
      (_) => const [AgentStep.say('Added the receipt.')],
    ]);
    AgentConnection idle() =>
        ScriptedAgent.repeating((_) => const [AgentStep.say('Ready.')]);
    await tester.pumpWidget(
      WaypointApp(
        createAgents: () => Agents(
          trip: idle(),
          booking: idle(),
          plan: idle(),
          expenses: agent,
          arrival: idle(),
        ),
      ),
    );
    await _settle(tester);
    await _open(tester, '/expenses/paris/report');
    final context = tester.element(find.byType(TandemScope).last);
    final cubit = context.read<ExpensesReportCubit>();
    final reports = context.read<ReportsCubit>();
    expect(agent.requests, isEmpty);
    expect(cubit.form.lines, isEmpty);
    expect(reports.report(TripId('paris')).lines, isEmpty);

    await tester.tap(find.text('Add forwarded receipts'));
    await _settle(tester);

    expect(agent.requests, isNotEmpty);
    expect(
      agent.requests.first['messages'],
      contains(
        allOf(
          containsPair('content', startsWith('Add these forwarded receipts')),
          containsPair('content', isNot(contains('submit'))),
        ),
      ),
    );
    expect(cubit.form.isClaimed(ReceiptId('R-0916-1')), isTrue);
    expect(reports.report(TripId('paris')).lines, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a new report deep link owns a new form while submission completes',
    (tester) async {
      await tester.pumpWidget(const WaypointApp(createAgents: _idleAgents));
      await _settle(tester);
      await _open(tester, '/expenses/paris/report');
      final firstContext = tester.element(find.byType(TandemScope).last);
      final first = firstContext.read<ExpensesReportCubit>();
      final reports = firstContext.read<ReportsCubit>();
      first.addExpense('R-0916-1', 12);
      final submitting = first.submitReport();
      await tester.pump();

      await _open(tester, '/expenses/berlin/report');
      final next = tester
          .element(find.byType(TandemScope).last)
          .read<ExpensesReportCubit>();
      final submitted = await submitting;

      expect(
        tester
            .widget<ExpensesReportPage>(find.byType(ExpensesReportPage))
            .tripId,
        'berlin',
      );
      expect(next.trip.id, TripId('berlin'));
      expect(next.form.receipts, isEmpty);
      expect(identical(first, next), isFalse);
      expect(first.form.isDisposed, isTrue);
      expect(
        reports.report(TripId('paris')).submitted?.value,
        submitted.confirmation,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Agents _idleAgents() {
  AgentConnection idle() =>
      ScriptedAgent.repeating((request) => const [AgentStep.say('Ready.')]);
  return Agents(
    trip: idle(),
    booking: idle(),
    plan: idle(),
    expenses: idle(),
    arrival: idle(),
  );
}

Future<void> _open(WidgetTester tester, String location) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': location}),
    ),
    (data) {},
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
