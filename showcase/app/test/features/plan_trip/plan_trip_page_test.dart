import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/app.dart';
import 'package:waypoint/features/plan_trip/plan_trip_cubit.dart';
import 'package:waypoint/features/plan_trip/plan_trip_state.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  testWidgets('an invitation waits for an explicit planning request', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('set_city', {'city': 'Vienna'}),
      ],
      (_) => const [AgentStep.say('Started planning.')],
    ]);
    await tester.pumpWidget(
      WaypointApp(
        createAgents: () => Agents(
          trip: _idle(),
          booking: _idle(),
          plan: agent,
          expenses: _idle(),
          arrival: _idle(),
        ),
      ),
    );
    await _settle(tester);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('pushRouteInformation', {
          'location': '/trips/plan-trip?invitation=vienna',
        }),
      ),
      (data) {},
    );
    await _settle(tester);
    final context = tester.element(find.text('Plan from invitation'));
    final cubit = context.read<PlanTripCubit>();
    final session = TandemSessionScope.of(context);
    final invitation = const Inbox().invitation(TripId('vienna'));
    if (invitation == null) fail('The invitation is in the demo inbox.');

    expect(agent.requests, isEmpty);
    expect(session.items, isEmpty);
    expect(cubit.state, PlanTripState());
    expect(cubit.form.city.fieldValue, isNull);
    expect(cubit.form.value.wasModified, isFalse);

    await tester.tap(find.text('Plan from invitation'));
    await _settle(tester);

    expect(agent.requests, isNotEmpty);
    final request = session.items.whereType<UserMessage>().single;
    expect(request.fromApp, isFalse);
    expect(request.text, contains(invitation.body));
    expect(cubit.form.city.fieldValue, 'Vienna');
    expect(tester.takeException(), isNull);
  });
}

AgentConnection _idle() =>
    ScriptedAgent.repeating((request) => const [AgentStep.say('Ready.')]);

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
