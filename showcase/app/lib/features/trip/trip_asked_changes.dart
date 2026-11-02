import 'package:tandem/tandem.dart';
import 'package:waypoint/features/trip/booking_changes.dart';

final class AskedChanges() {
  final _asked = <String, BookingChanges>{};

  void remember(ApprovalRequest request, BookingChanges changes) =>
      _asked.putIfAbsent(request.toolCallId, () => changes);

  BookingChanges of(ApprovalRequest request) =>
      _asked[request.toolCallId] ??
      (throw StateError('The approval has no captured booking changes.'));
}
