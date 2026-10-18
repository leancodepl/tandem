import 'package:example/agent_chat.dart';
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
  Widget build(BuildContext context) {
    final items = context.watch<ShoppingListCubit>().items;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: ListView(
              children: [for (final item in items) ListTile(title: Text(item))],
            ),
          ),
          const SizedBox(width: 360, child: AgentChat()),
        ],
      ),
    );
  }
}
