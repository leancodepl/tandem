import 'package:greenhouse_app/contracts.dart';
import 'package:tandem/tandem.dart';

part 'route_agent.g.dart';

/// One agent for the whole app, whose list follows the route.
@TandemAgent()
final class RouteAgent() with _$RouteAgent {
  static const _bench = '/bench';

  String route = _bench;
  PlantDTO? benchPlant;
  PlantDTO? cuttingsPlant;

  @override
  List<AgentCapability> get agentCapabilities => switch (route) {
    _bench => [.sees(repotted), .calls(openCuttings)],
    '/cuttings' => [.sees(rooting), .calls(openBench)],
    _ => [.calls(openBench)],
  };

  @override
  Stream<Object?> get changes => const Stream.empty();

  /// The plant repotted on the bench.
  PlantDTO? get repotted => benchPlant;

  /// The cutting that roots first on the propagation tray.
  PlantDTO? get rooting => cuttingsPlant;

  /// Opens the propagation tray.
  void openCuttings() => route = '/cuttings';

  /// Opens the bench.
  void openBench() => route = _bench;
}
