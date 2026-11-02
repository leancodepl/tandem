import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

part 'arrival_arrangements.g.dart';

@CopyWith()
final class const ArrivalArrangements({
  final RideBooking? ride,
  final RideId? pendingRide,
  final SentHostMessage? hostMessage,
  final EarlyCheckIn? earlyCheckIn,
}) with Equatable {
  @override
  List<Object?> get props => [ride, pendingRide, hostMessage, earlyCheckIn];
}

final class const RideBooking({
  required final RideId rideId,
  required final BookingReference reference,
}) with Equatable {
  @override
  List<Object?> get props => [rideId, reference];
}

final class const SentHostMessage({
  required final String phone,
  required final String text,
}) with Equatable {
  @override
  List<Object?> get props => [phone, text];
}

final class const EarlyCheckIn({
  required final BookingReference confirmation,
  required final DateTime roomReady,
}) with Equatable {
  @override
  List<Object?> get props => [confirmation, roomReady];
}
