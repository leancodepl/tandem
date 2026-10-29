import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/features/booking/booking_cubit.dart';
import 'package:waypoint/features/booking/booking_form_controller.dart';
import 'package:waypoint/l10n/app_localizations.dart';

void main() {
  test('a lost connection and a failed run are failures, a stop is not', () {
    expect(AgentFailure.of(.connectionLost), isA<AgentUnreachable>());
    expect(AgentFailure.of(.runFailed), isA<AgentRunFailed>());
    expect(AgentFailure.of(.stopped), isNull);
    expect(AgentFailure.of(.startedOver), isNull);
  });

  test('an unreachable agent asks the traveller to check the connection', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(
      l10n.agentFailure(const AgentUnreachable()),
      'Waypoint cannot reach the assistant. Check your connection.',
    );
    expect(
      l10n.agentFailure(const AgentRunFailed()),
      'The assistant ran into a problem.',
    );
  });

  testWidgets("Retry sends the traveller's message again", (tester) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.fail('Overloaded.')],
      (_) => const [AgentStep.say('Filled in.')],
    ]);
    final session = await _open(tester, agent);

    session.send('Fill in the booking.');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<AgentRunException>());
    expect(session.failure, isA<AgentRunFailed>());

    session.retry();
    await tester.pumpAndSettle();

    expect(session.failure, isNull);
    expect(_lastUserText(agent.requests.last), 'Fill in the booking.');
  });

  testWidgets("Retry wakes the agent again for the app's notes", (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(Future.error(const _Offline()))],
      (_) => const [AgentStep.say('Drawn.')],
    ]);
    final session = await _open(tester, agent);

    session
      ..note('The traveller opened the form.')
      ..wake();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<_Offline>());
    expect(session.failure, isA<AgentUnreachable>());

    session.retry();
    await tester.pumpAndSettle();

    final request = agent.requests.last;
    expect(_lastUserText(request), contains('The app sent this'));
    expect('${request['context']}', contains('The traveller opened the form.'));
  });
}

Future<TandemSession> _open(WidgetTester tester, AgentConnection agent) async {
  final form = BookingFormController(
    tripStart: DateTime(2026, 10, 28),
    tripEnd: DateTime(2026, 10, 29),
  );
  addTearDown(form.dispose);
  final booking = BookingCubit(form: form);
  addTearDown(booking.close);
  late TandemSession session;
  await tester.pumpWidget(
    TandemScope.connected(
      surface: (context) => booking,
      connection: agent,
      approvals: const .none(),
      child: Builder(
        builder: (context) {
          session = TandemSessionScope.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return session;
}

String? _lastUserText(Map<String, Object?> request) =>
    switch (request['messages']) {
      [..., {'role': 'user', 'content': final String text}] => text,
      _ => null,
    };

final class const _Offline() implements Exception;
