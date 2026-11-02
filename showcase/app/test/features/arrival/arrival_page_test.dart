import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/app.dart';
import 'package:waypoint/features/arrival/arrival_arrangements_cubit.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';

void main() {
  testWidgets('arrival starts only after an explicit request', (tester) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('request_early_check_in')],
      (_) => const [AgentStep.say('The room will be ready early.')],
    ]);
    AgentConnection idle() =>
        ScriptedAgent.repeating((_) => const [AgentStep.say('Ready.')]);
    await tester.pumpWidget(
      WaypointApp(
        createAgents: () => Agents(
          trip: idle(),
          booking: idle(),
          plan: idle(),
          expenses: idle(),
          arrival: agent,
        ),
      ),
    );
    await _settle(tester);
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('pushRouteInformation', {
          'location': '/trips/berlin/arrival',
        }),
      ),
      (data) {},
    );
    await _settle(tester);

    final context = tester.element(find.byType(TandemScope).last);
    final arrival = context.read<ArrivalCubit>();
    final arrangements = context.read<ArrivalArrangementsCubit>();
    expect(agent.requests, isEmpty);
    expect(arrangements.state, isEmpty);
    expect(arrival.arrival.hotel.roomReady, isNull);

    await tester.tap(find.text('Plan my arrival'));
    await _settle(tester);

    expect(agent.requests, isNotEmpty);
    expect(
      agent.requests.first['messages'],
      contains(
        containsPair(
          'content',
          'Plan my arrival from landing to the first meeting.',
        ),
      ),
    );
    expect(arrival.arrival.hotel.roomReady, DateTime(2026, 10, 28, 13));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
