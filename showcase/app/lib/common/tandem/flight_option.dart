/// A flight as find_flights gives it to the agent.
final class const FlightOption({
  required final String number,
  required final String departs,
  required final String arrives,
  required final int fare,

  /// Why the traveller cannot take it, or null when they can.
  final String? unavailable,
});
