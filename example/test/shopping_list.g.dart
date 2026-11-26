// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ShoppingListCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ShoppingListCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.items)
            .as('items', 'What is on the shopping list now.', .list(.string)),
      ],
      calls: [
        AgentTool(
          surface.add,
          name: ShoppingListCubitTool.add,
          description: 'Adds [item] to the list.',
          parameters: [const AgentParameter<String>('item', .string)],
          invoke: (args) {
            surface.add(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.remove,
          name: ShoppingListCubitTool.remove,
          description: 'Removes [item] from the list.',
          parameters: [const AgentParameter<String>('item', .string)],
          invoke: (args) {
            surface.remove(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.clear,
          name: ShoppingListCubitTool.clear,
          description: 'Empties the list.',
          parameters: [],
          invoke: (args) async {
            await surface.clear();
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

/// The names the agent knows the methods of [ShoppingListCubit] by.
// `enum ShoppingListCubitTool()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum ShoppingListCubitTool implements ToolName {
  add,
  remove,
  clear;

  @override
  String get value => switch (this) {
    add => 'add',
    remove => 'remove',
    clear => 'clear',
  };

  @override
  String toString() => value;
}

extension on ShoppingListCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('items', items),
    .calls(add),
    .calls(remove),
    if (items.isNotEmpty) .callsWithApproval(clear),
  ];
}
