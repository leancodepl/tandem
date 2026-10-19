import 'package:example/agent_chat.dart';
import 'package:example/agent_workspace.dart';
import 'package:example/item_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

part 'shopping_list.g.dart';

class const ShoppingListState({final List<String> items = const []});

@TandemAgent()
class ShoppingListCubit()
    extends Cubit<ShoppingListState>
    with _$ShoppingListCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(items),
    .calls(add),
    .calls(remove),
    if (items.isNotEmpty) .callsWithApproval(clear),
  ];

  @override
  Stream<Object?> get changes => stream;

  /// What is on the shopping list now.
  List<String> get items => state.items;

  /// Adds [item] to the list.
  void add(String item) => emit(.new(items: [...items, item]));

  /// Removes [item] from the list.
  void remove(String item) => emit(.new(items: [...items]..remove(item)));

  /// Empties the list.
  void clear() => emit(const .new());
}

void main() => runApp(
  MaterialApp(
    home: ShoppingListScreen(
      connection: HttpAgentConnection(Uri.parse('http://localhost:8000/agent')),
    ),
  ),
);

final class const ShoppingListScreen({
  super.key,
  required final AgentConnection connection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ShoppingListCubit(),
    child: TandemScope.connected(
      surface: (context) => context.read<ShoppingListCubit>(),
      connection: connection,
      approvals: const .fromState(),
      child: const _ShoppingListView(),
    ),
  );
}

final class const _ShoppingListView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: AgentWorkspace(
      title: 'Shopping list',
      chat: AgentChat(suggestion: 'Add milk and bread, then empty the list.'),
      child: _Items(),
    ),
  );
}

final class const _Items() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ShoppingListCubit>();

    return Column(
      children: [
        Expanded(
          child: switch (cubit.items) {
            [] => const Center(child: Text('Your shopping list is empty.')),
            final items => ListView(
              padding: const .symmetric(vertical: 8),
              children: [
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: Text(item),
                    trailing: IconButton(
                      tooltip: 'Remove $item',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => cubit.remove(item),
                    ),
                  ),
              ],
            ),
          },
        ),
        ItemInput(label: 'Add an item', onAdd: cubit.add),
      ],
    );
  }
}
