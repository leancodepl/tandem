// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_list.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$TodoList implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as TodoList;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.todos,
          'todos',
          'The to-dos as the user sees them, oldest first.',
          (todos) => todos,
        ),
      ],
      calls: [
        AgentTool(
          surface.add,
          name: 'add',
          description: 'Adds [todo] at the end of the list.',
          parameters: const {
            'type': 'object',
            'properties': {
              'todo': {'type': 'string'},
            },
            'required': ['todo'],
          },
          invoke: (args) {
            surface.add(args.read('todo'));
            return null;
          },
        ),
        AgentTool(
          surface.clear,
          name: 'clear',
          description: 'Removes every to-do.',
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
