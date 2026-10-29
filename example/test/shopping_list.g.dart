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
          name: 'add',
          description: 'Adds [item] to the list.',
          parameters: [const AgentParameter<String>('item', .string)],
          invoke: (args) {
            surface.add(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.remove,
          name: 'remove',
          description: 'Removes [item] from the list.',
          parameters: [const AgentParameter<String>('item', .string)],
          invoke: (args) {
            surface.remove(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.clear,
          name: 'clear',
          description: 'Empties the list.',
          parameters: [],
          invoke: (args) async {
            await surface.clear();
            return null;
          },
        ),
      ],
    );
  }
}
