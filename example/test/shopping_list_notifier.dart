import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tandem/tandem.dart';

part 'shopping_list_notifier.g.dart';

@TandemAgent()
final class ShoppingListNotifier()
    extends ChangeNotifier
    with _$ShoppingListNotifier {
  final _changes = StreamController<Object?>.broadcast();
  var _items = const <String>[];

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(items),
    .callsWithApproval(clear),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _changes.add(null);
  }

  @override
  void dispose() {
    unawaited(_changes.close());
    super.dispose();
  }

  /// What is on the shopping list now.
  List<String> get items => _items;

  void add(String item) {
    _items = [..._items, item];
    notifyListeners();
  }

  /// Empties the list.
  void clear() {
    _items = const [];
    notifyListeners();
  }
}
