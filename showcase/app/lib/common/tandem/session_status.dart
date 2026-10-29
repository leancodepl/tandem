import 'package:tandem/tandem.dart';

extension SessionWork on SessionStatus {
  /// The agent thinks or a method of the screen runs, so the screen shows
  /// its work in a `WorkStatus`.
  bool get isWorking => this is Thinking || this is Calling;

  /// A run is under way, also while it stops, so the composer shows Stop
  /// in place of Send.
  bool get isRunning => isWorking || this is Stopping;

  /// The agent works on its own, so the traveller can stop it. A call the
  /// traveller approved runs to its end.
  bool get isStoppable => switch (this) {
    Thinking() || Calling(approved: false) => true,
    _ => false,
  };
}
