A shopping list the agent can read and change. It can empty the list only after the user approves, and only when there is something on it.

<!-- example/lib/shopping_list/shopping_list.dart -->
```dart
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
  final String suggestion = 'Add milk and bread, then empty the list.',
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ShoppingListCubit(),
    child: TandemScope.connected(
      surface: (context) => context.read<ShoppingListCubit>(),
      connection: connection,
      approvals: const .fromState(),
      child: _ShoppingListView(suggestion),
    ),
  );
}

final class const _ShoppingListView(final String suggestion)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AgentWorkspace(
      title: 'Shopping list',
      chat: AgentChat(suggestion: suggestion),
      child: const _Items(),
    ),
  );
}
```

[`agent_chat.dart`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_chat.dart) is the chat of the example: copy it into your app, make its texts and look your own, and import it from there. [`AgentWorkspace`](https://github.com/leancodepl/tandem/blob/main/example/lib/agent_workspace.dart) puts the list and the chat side by side, or one above the other on a phone, and `_Items` is the list itself, with buttons to remove an item and a field to add one ([the whole file](https://github.com/leancodepl/tandem/blob/main/example/lib/shopping_list/shopping_list.dart)). `approvals: const .fromState()` lets the chat draw the card for `clear`. Run `dart run build_runner build` to generate `shopping_list.g.dart`, then start an AG-UI agent on `localhost:8000` that puts `context` into the model's prompt.

No agent yet? `ScriptedAgent` plays a script in its place, with no backend and no API key. Run this file with `flutter run -t` and its path:

<!-- example/lib/shopping_list/try_it.dart -->
```dart
import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:tandem/testing.dart';

// Plays these turns whatever the user writes. A run past the script fails.
final _agent = ScriptedAgent([
  (_) => const [
    AgentStep.callTool('add', {'item': 'Milk'}),
    AgentStep.callTool('add', {'item': 'Bread'}),
  ],
  (_) => const [
    AgentStep.say('Added milk and bread. Shall I empty the list?'),
    AgentStep.callTool('clear'),
  ],
  (_) => const [AgentStep.say('Done.')],
]);

void main() =>
    runApp(MaterialApp(home: ShoppingListScreen(connection: _agent)));
```

The [example gallery](https://github.com/leancodepl/tandem/blob/main/example/README.md) runs this screen and five more with scripted agents. More screens to copy, with Riverpod, provider, a dialog for approvals and a button instead of a chat, are in [doc/examples.md](https://github.com/leancodepl/tandem/blob/main/doc/examples.md).
