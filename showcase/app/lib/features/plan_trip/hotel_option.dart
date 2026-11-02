/// A hotel as find_hotels gives it to the agent.
final class const HotelOption({
  required final String id,
  required final String name,
  required final int nightly,
  required final int walkMinutes,

  /// Why the traveller cannot take it, or null when they can.
  final String? unavailable,
});
