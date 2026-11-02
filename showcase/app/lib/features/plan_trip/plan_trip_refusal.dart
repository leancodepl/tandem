import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const PlanRefusal() {
  /// The refusal in English, for the agent.
  String get forAgent;
}

final class const CityNotSet() extends PlanRefusal {
  @override
  String get forAgent => 'Set the city first';
}

final class const WrongRoute(
  final Flight flight, {
  required final AirportCode origin,
  required final AirportCode destination,
}) extends PlanRefusal {
  @override
  String get forAgent =>
      'Flight ${flight.number} does not fly from $origin to $destination';
}

final class const HotelNotInCity(final Hotel hotel, final String city)
    extends PlanRefusal {
  @override
  String get forAgent => '${hotel.name} is not in $city';
}

final class const BreaksPlanPolicy(final PolicyBreach breach)
    extends PlanRefusal {
  static BreaksPlanPolicy? of(PolicyBreach? breach) => switch (breach) {
    final breach? => BreaksPlanPolicy(breach),
    null => null,
  };

  @override
  String get forAgent => breach.forAgent;
}
