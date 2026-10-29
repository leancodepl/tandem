import 'package:flutter/widgets.dart';

/// A key per itinerary item, so that a card keeps its state when it moves
/// to another day and the screen can scroll to it.
final class ItemKeys() {
  final _keys = <String, GlobalKey>{};

  GlobalKey operator [](String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  void reveal(String id) {
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
