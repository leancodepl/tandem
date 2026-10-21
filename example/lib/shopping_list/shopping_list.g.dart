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
        AgentView.of(
          () => surface.items,
          'items',
          'What is on the shopping list now.',
          (items) => items,
        ),
      ],
      calls: [
        AgentTool(
          surface.add,
          name: 'add',
          description: 'Adds [item] to the list.',
          parameters: const {
            'type': 'object',
            'properties': {
              'item': {'type': 'string'},
            },
            'required': ['item'],
          },
          invoke: (args) {
            surface.add(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.remove,
          name: 'remove',
          description: 'Removes [item] from the list. Refuses names absent from the current list.',
          parameters: const {
            'type': 'object',
            'properties': {
              'item': {'type': 'string'},
            },
            'required': ['item'],
          },
          invoke: (args) {
            surface.remove(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.clear,
          name: 'clear',
          description: 'Empties the list.',
          parameters: const {'type': 'object', 'properties': {}},
          invoke: (args) {
            surface.clear();
            return null;
          },
        ),
      ],
    );
  }
}
