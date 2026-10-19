import 'package:example/agent_chat.dart';
import 'package:example/agent_workspace.dart';
import 'package:example/item_input.dart';
import 'package:example/recipes/riverpod/cart_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tandem/tandem.dart';

/// A shopping cart on Riverpod with the agent's chat. Needs a
/// `ProviderScope` above it.
final class const CartScreen({
  super.key,
  required final AgentConnection connection,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => TandemScope.connected(
    surface: (context) => ref.read(cartProvider.notifier),
    connection: connection,
    approvals: const .fromState(),
    child: const Scaffold(
      body: AgentWorkspace(
        title: 'Shopping cart',
        chat: AgentChat(
          suggestion: 'Add a keyboard and a USB-C cable, then check out.',
        ),
        child: _Cart(),
      ),
    ),
  );
}

final class const _Cart() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: switch (ref.watch(cartProvider)) {
            [] => const Center(child: Text('Your cart is empty.')),
            final items => ListView(
              padding: const .symmetric(vertical: 8),
              children: [
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(item),
                    trailing: IconButton(
                      tooltip: 'Remove $item',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => cart.remove(item),
                    ),
                  ),
              ],
            ),
          },
        ),
        ItemInput(label: 'Add a product', onAdd: cart.add),
      ],
    );
  }
}
