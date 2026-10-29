import 'package:tandem/tandem.dart';

/// The agents of Waypoint's screens, one connection each.
final class Agents {
  const new({
    required this.trip,
    required this.booking,
    required this.plan,
    required this.expenses,
    required this.arrival,
  });

  /// The agent at `uri` for the trip, and beside it, each with its own
  /// instruction, at `uri/booking` for the booking form, at `uri/plan` for a
  /// new trip, at `uri/expenses` for an expense report and at `uri/arrival`
  /// for the arrival day.
  new http(Uri uri)
    : trip = HttpAgentConnection(uri),
      booking = HttpAgentConnection(uri.replace(path: '${uri.path}/booking')),
      plan = HttpAgentConnection(uri.replace(path: '${uri.path}/plan')),
      expenses = HttpAgentConnection(uri.replace(path: '${uri.path}/expenses')),
      arrival = HttpAgentConnection(uri.replace(path: '${uri.path}/arrival'));

  final AgentConnection trip;
  final AgentConnection booking;
  final AgentConnection plan;
  final AgentConnection expenses;
  final AgentConnection arrival;
}
