import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/agents.dart';

void main() {
  test(
    'screen endpoints share a base path with or without a trailing slash',
    () {
      for (final path in ['/nested/agent', '/nested/agent/']) {
        final agents = Agents.http(
          Uri.parse('http://localhost:8010$path?token=x'),
        );
        final endpoints = [
          agents.trip,
          agents.booking,
          agents.plan,
          agents.expenses,
          agents.arrival,
        ].cast<HttpAgentConnection>().map((agent) => agent.endpoint).toList();

        expect(endpoints.map((endpoint) => endpoint.path), [
          '/nested/agent',
          '/nested/agent/booking',
          '/nested/agent/plan',
          '/nested/agent/expenses',
          '/nested/agent/arrival',
        ]);
        expect(
          endpoints.map((endpoint) => endpoint.query),
          everyElement('token=x'),
        );
      }
    },
  );
}
