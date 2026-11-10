import 'package:tandem/tandem.dart';
import 'package:waypoint/features/trip/booking_changes.dart';

final class AskedChanges() {
  final _asked = <Object, BookingChanges>{};

  void remember(ApprovalRequest request, BookingChanges changes) =>
      _asked.putIfAbsent(request.key, () => changes);

  BookingChanges of(ApprovalRequest request) =>
      _asked[request.key] ??
      (throw StateError('The approval has no captured booking changes.'));
}
