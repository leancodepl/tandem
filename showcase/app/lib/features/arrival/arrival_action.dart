/// What the agent or a button of its view asks to do in the traveller's
/// name, read from the tool name and arguments that Tandem reports. No other
/// file names these tools or their arguments.
sealed class const ArrivalAction() {
  /// The action of a call of [tool]. Its [arguments] are known once the
  /// call has run, and missing while it runs.
  static ArrivalAction? of(
    String tool, [
    Map<String, Object?> arguments = const {},
  ]) => switch (tool) {
    'book_ride' => BookRide(switch (arguments['rideId']) {
      final String rideId => rideId,
      _ => null,
    }),
    'message_host' => const MessageHost(),
    _ => null,
  };
}

final class const BookRide(final String? rideId) extends ArrivalAction;

final class const MessageHost() extends ArrivalAction;
