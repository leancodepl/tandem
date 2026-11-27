// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_start.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ShoppingCubit implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ShoppingCubit;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.items)
            .as('items', 'What is on the shopping list now.', .list(.string)),
      ],
      calls: [
        AgentTool(
          surface.add,
          name: ShoppingCubitTool.add,
          description: 'Adds [item] to the list.',
          parameters: [const AgentParameter<String>('item', .string)],
          invoke: (args) {
            surface.add(args.read('item'));
            return null;
          },
        ),
        AgentTool(
          surface.clear,
          name: ShoppingCubitTool.clear,
          description: 'Removes every item from the list.',
          parameters: [],
          invoke: (args) {
            surface.clear();
            return null;
          },
        ),
      ],
      capabilities: () => surface._$agentCapabilities,
    );
  }
}

/// The names the agent knows the methods of [ShoppingCubit] by.
// `enum ShoppingCubitTool()` needs Dart 3.13 in the app.
// ignore: use_primary_constructors
enum ShoppingCubitTool implements ToolName {
  add,
  clear;

  @override
  String get value => switch (this) {
    add => 'add',
    clear => 'clear',
  };

  @override
  String toString() => value;
}

extension on ShoppingCubit {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('items', items),
    .calls(add),
    .callsWithApproval(clear),
  ];
}

// **************************************************************************
// CatalogGenerator
// **************************************************************************

mixin _$ShoppingCatalog implements AgentCatalog {
  @override
  String get guidelines =>
      'Suggest items the list does not have yet. Draw one Suggestions with a Suggestion for each item. Its onAdd calls add with that item.';

  @override
  List<Map<String, Object?>> get example => const [
    {
      'id': 'root',
      'component': 'Suggestions',
      'children': ['milk'],
    },
    {
      'id': 'milk',
      'component': 'Suggestion',
      'item': 'milk',
      'onAdd': {
        'action': {
          'event': {
            'name': 'add',
            'context': {'item': 'milk'},
          },
        },
      },
    },
  ];

  @override
  List<AgentComponent> get components => [
    AgentComponent<Suggestions>.of(
      name: 'Suggestions',
      description: 'Suggested items, one below another.',
      properties: (property) => [property.children('children')],
      build: (args) => Suggestions(children: args.children('children')),
    ),
    AgentComponent<Suggestion>.of(
      name: 'Suggestion',
      description: 'An item to add to the list, with a button that adds it.',
      properties: (property) => [
        property('item', (widget) => widget.item).value(.string),
        property.press('onAdd'),
      ],
      build: (args) =>
          Suggestion(item: args.value('item'), onAdd: args.press('onAdd')),
    ),
  ];
}
