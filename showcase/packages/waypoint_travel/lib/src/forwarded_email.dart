import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/trip.dart';
import 'package:waypoint_travel/src/value_objects.dart';

/// An e-mail the traveller forwarded to Waypoint, with what it means for
/// one of their trips.
final class const ForwardedEmail({
  required final String from,
  required final String subject,
  required final DateTime received,
  required final String body,
  required final TripId tripId,
  required final EmailNews news,
}) with Equatable {
  @override
  List<Object?> get props => [from, subject, received, body, tripId, news];

  /// Whether the trip as booked already follows the e-mail. An invitation
  /// is done once its trip exists, so [booked] is null until then.
  bool isDoneIn(Itinerary? booked) => switch ((news, booked)) {
    (TripInvitation(), final booked) => booked != null,
    // An expense report, not the trip, settles a receipt.
    (Receipt(), _) => false,
    (_, null) => false,
    (MeetingMoved(:final meetingId, :final start), final booked?) =>
      booked.meeting(meetingId)?.start.isAtSameMomentAs(start) ?? false,
    (HotelConfirmation(:final number), final booked?) =>
      booked.hotel?.confirmation == number,
  };
}

/// What an e-mail changes for its trip.
sealed class const EmailNews() with Equatable;

final class const MeetingMoved({
  required final MeetingId meetingId,
  required final DateTime start,
}) extends EmailNews {
  @override
  List<Object?> get props => [meetingId, start];
}

/// An invitation to meetings that need a trip, which [ForwardedEmail.tripId]
/// names before it exists.
final class const TripInvitation({
  required final String city,
  required final String client,
}) extends EmailNews {
  @override
  List<Object?> get props => [city, client];
}

/// A receipt of the trip, for its expense report.
final class Receipt({
  required final ReceiptId id,
  required final String merchant,
  required final ExpenseCategory category,
  required final DateTime day,

  required final Money paid,
}) extends EmailNews {
  this {
    requireSupportedWholeMoney(paid, 'paid');
    if (paid >= wholeMoney(0)) return;
    throw ArgumentError.value(paid, 'paid', 'Cannot be negative');
  }

  @override
  List<Object?> get props => [id, merchant, category, day, paid];
}

enum ExpenseCategory() {
  taxi,
  meal,
  transport,
}

/// A hotel the traveller booked themselves, to add to the trip.
final class const HotelConfirmation(final BookingReference number)
    extends EmailNews {
  @override
  List<Object?> get props => [number];
}
