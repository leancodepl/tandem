import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tandem/tandem.dart';

part 'cart_notifier.g.dart';

// Written by hand: riverpod_generator writes a `_$CartNotifier` too.
final cartProvider = NotifierProvider.autoDispose(CartNotifier.new);

@TandemAgent()
class CartNotifier() extends Notifier<List<String>> with _$CartNotifier {
  final _changes = StreamController<Object?>.broadcast();

  @override
  List<String> build() {
    // Riverpod drops this listener when it builds again, so it is never
    // there twice.
    listenSelf((_, next) => _changes.add(next));
    return const [];
  }

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(items),
    .calls(add),
    .calls(remove),
    if (items.isNotEmpty) .callsWithApproval(checkout),
  ];

  @override
  Stream<Object?> get changes => _changes.stream;

  // Protected, so riverpod_lint does not ask to read it through `state`.
  /// What is in the cart now.
  @protected
  List<String> get items => state;

  /// Puts [item] in the cart.
  void add(String item) => state = [...state, item];

  /// Takes [item] out of the cart.
  void remove(String item) => state = [...state]..remove(item);

  /// Orders everything in the cart and empties it.
  void checkout() => state = const [];
}
