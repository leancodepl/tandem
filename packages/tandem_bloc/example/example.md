A shopping list the agent can read and change. It can empty the list only after the user approves, and only when there is something on it.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

import 'agent_chat.dart';

part 'main.g.dart';

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

  /// What is on the shopping list now.
  List<String> get items => state.items;

  /// Adds [item] to the list.
  void add(String item) => emit(.new(items: [...items, item]));

  /// Removes [item] from the list.
  void remove(String item) => emit(.new(items: [...items]..remove(item)));

  /// Empties the list.
  void clear() => emit(const .new());
}

void main() => runApp(const MaterialApp(home: ShoppingListScreen()));

final class const ShoppingListScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ShoppingListCubit(),
    child: TandemScope<ShoppingListCubit>(
      agent: Uri.parse('http://localhost:8000/agent'),
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
```

Copy [`agent_chat.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) next to it and make its texts and look your own. Run `dart run build_runner build` to generate `main.g.dart`, then start an AG-UI agent on `localhost:8000` that puts `context` into the model's prompt.
