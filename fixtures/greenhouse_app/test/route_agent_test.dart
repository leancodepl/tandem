import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/route_agent.dart';
import 'package:tandem/testing.dart';

void main() {
  test('two getters of one type keep their names on every route', () async {
    final agent = RouteAgent();
    List<Object?> seen() => [
      for (final entry in AgentListing.of(agent).context) entry['description'],
    ];

    final onBench = seen();
    await AgentListing.of(agent).call('open_cuttings', {});
    final onCuttings = seen();
    agent.route = '/settings';

    expect(onBench, ['repotted: The plant repotted on the bench.']);
    expect(onCuttings, [
      'rooting: The cutting that roots first on the propagation tray.',
    ]);
    expect(seen(), isEmpty);
    expect(AgentListing.of(agent).toolNames, ['open_bench']);
  });
}
