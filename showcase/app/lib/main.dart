import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/app.dart';
import 'package:waypoint/common/logging/logging.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

/// Scripts in place of the agent: no server and no API key.
const _scripted = bool.fromEnvironment('SCRIPTED');

/// The agent's AG-UI endpoint, `showcase/agent` on this computer unless
/// given. An Android emulator reaches the computer at 10.0.2.2.
final _agent = switch (const String.fromEnvironment('AGENT')) {
  '' when defaultTargetPlatform == .android => 'http://10.0.2.2:8010/agent',
  '' => 'http://localhost:8010/agent',
  final url => url,
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setUpLogging();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(
    WaypointApp(
      createAgents: () => _scripted
          ? Agents(
              trip: scriptedTripAgent(),
              booking: scriptedBookingAgent(),
              plan: scriptedPlanAgent(),
              expenses: scriptedExpensesAgent(),
              arrival: scriptedArrivalAgent(),
            )
          : .http(Uri.parse(_agent)),
    ),
  );
}
