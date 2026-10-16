// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ShoppingListCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final cubit = this as ShoppingListCubit;
    return AgentSchema(
      sees: [
        AgentView.of(
          () => cubit.items,
          'items',
          'What is on the shopping list now.',
          (items) => items,
        ),
      ],
      calls: [
        AgentTool(
          cubit.add,
          name: 'add',
          description: 'Adds [item] to the list.',
          parameters: {
            'type': 'object',
            'properties': {
              'item': {'type': 'string'},
            },
            'required': ['item'],
          },
          invoke: (args) {
            cubit.add(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          cubit.remove,
          name: 'remove',
          description: 'Removes [item] from the list.',
          parameters: {
            'type': 'object',
            'properties': {
              'item': {'type': 'string'},
            },
            'required': ['item'],
          },
          invoke: (args) {
            cubit.remove(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          cubit.clear,
          name: 'clear',
          description: 'Empties the list.',
          parameters: {'type': 'object', 'properties': {}},
          invoke: (args) {
            cubit.clear();
            return null;
          },
        ),
      ],
    );
  }
}
