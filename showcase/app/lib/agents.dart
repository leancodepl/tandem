import 'package:tandem/tandem.dart';

final class const Agents({
  required final AgentConnection trip,
  required final AgentConnection booking,
  required final AgentConnection plan,
  required final AgentConnection expenses,
  required final AgentConnection arrival,
}) {
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
