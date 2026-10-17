A shopping list the agent can read and change. It can empty the list only after the user approves, and only when there is something on it. The full order-desk demo, with its agent, is in [`example/`](https://github.com/leancodepl/tandem/tree/main/example).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

part 'main.g.dart';

class const ShoppingListState({final List<String> items = const []});

class ShoppingListCubit() extends Cubit<ShoppingListState> with _$ShoppingListCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agent => [
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

void main() => runApp(
  MaterialApp(
    home: BlocProvider(
      create: (_) => ShoppingListCubit(),
      child: TandemScope<ShoppingListCubit>(
        agent: Uri.parse('http://localhost:8000/agent'),
        child: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: BlocBuilder<ShoppingListCubit, ShoppingListState>(
                  builder: (context, state) => ListView(
                    children: [for (final item in state.items) ListTile(title: Text(item))],
                  ),
                ),
              ),
              const SizedBox(width: 360, child: TandemChat()),
            ],
          ),
        ),
      ),
    ),
  ),
);
```

Run `dart run build_runner build` to generate `main.g.dart`, then start any AG-UI agent on `localhost:8000`.
