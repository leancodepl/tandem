import 'package:tandem/tandem.dart';
import 'package:waypoint/features/arrival/arrival_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// What the agent or a button of its view asks to do in the traveller's
/// name, read from the tool name and arguments that Tandem reports. No other
/// file names these tools or their arguments.
sealed class const ArrivalAction() {
  /// The action of a call of [tool]. Its [arguments] are known once the
  /// call has run, and missing while it runs.
  static ArrivalAction? of(
    ToolName tool, [
    Map<String, Object?> arguments = const {},
  ]) {
    if (tool is! ArrivalCubitTool) return null;

    return switch (tool) {
      .bookRide => BookRide(switch (arguments['rideId']) {
        final String rideId => RideId.tryParse(rideId),
        _ => null,
      }),
      .messageHost => const MessageHost(),
      .requestEarlyCheckIn => null,
    };
  }
}

final class const BookRide(final RideId? rideId) extends ArrivalAction;

final class const MessageHost() extends ArrivalAction;
