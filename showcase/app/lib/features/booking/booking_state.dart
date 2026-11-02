import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint/features/booking/booking_draft.dart';

part 'booking_state.g.dart';

/// What the booking form shows besides its fields.
@CopyWith()
final class const BookingState._({
  /// The parts the agent filled in and the traveller has not changed.
  final Set<BookingPart> marked = const {},

  /// The stay is being added to the trip.
  final bool adding = false,
}) with Equatable {
  factory({Set<BookingPart> marked = const {}, bool adding = false}) =>
      BookingState._(marked: Set.unmodifiable(marked), adding: adding);

  @override
  List<Object?> get props => [marked, adding];
}
