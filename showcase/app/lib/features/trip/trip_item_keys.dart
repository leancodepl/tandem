import 'package:flutter/widgets.dart';
import 'package:waypoint/features/trip/trip_item_id.dart';

/// A key per itinerary item, so that a card keeps its state when it moves
/// to another day and the screen can scroll to it.
final class ItemKeys() {
  final _keys = <TripItemId, GlobalKey>{};

  GlobalKey operator [](TripItemId id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id.value));

  void reveal(TripItemId id) {
    final context = _keys[id]?.currentContext;
    if (context != null && context.mounted) {
      Scrollable.ensureVisible(
        context,
        alignment: .25,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
  }
}
