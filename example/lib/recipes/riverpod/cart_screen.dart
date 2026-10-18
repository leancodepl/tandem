import 'package:example/agent_chat.dart';
import 'package:example/recipes/riverpod/cart_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tandem/tandem.dart';

/// A shopping cart on Riverpod with the agent's chat beside it. Needs a
/// `ProviderScope` above it.
final class const CartScreen({
  super.key,
  required final AgentConnection connection,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);

    return TandemScope.connected(
      surface: (context) => ref.read(cartProvider.notifier),
      connection: connection,
      approvals: const .fromState(),
      child: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item),
                      trailing: IconButton(
                        tooltip: 'Remove $item',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () =>
                            ref.read(cartProvider.notifier).remove(item),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 360, child: AgentChat()),
          ],
        ),
      ),
    );
  }
}
