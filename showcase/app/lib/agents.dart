import 'package:tandem/tandem.dart';

/// The agents of Waypoint's screens, one connection each.
final class const Agents({
  required final AgentConnection trip,
  required final AgentConnection booking,
  required final AgentConnection plan,
  required final AgentConnection expenses,
  required final AgentConnection arrival,
}) {
  /// The agent at `uri` for the trip, and beside it, each with its own
  /// instruction, at `uri/booking` for the booking form, at `uri/plan` for a
  /// new trip, at `uri/expenses` for an expense report and at `uri/arrival`
  /// for the arrival day.
  factory http(Uri uri) {
    final endpoint = uri.replace(
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    );
    AgentConnection forScreen(String screen) =>
        HttpAgentConnection(endpoint.replace(path: '${endpoint.path}/$screen'));
    return Agents(
      trip: HttpAgentConnection(endpoint),
      booking: forScreen('booking'),
      plan: forScreen('plan'),
      expenses: forScreen('expenses'),
      arrival: forScreen('arrival'),
    );
  }
}
