// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_notifier.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$ShoppingListNotifier implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as ShoppingListNotifier;

    return AgentSchema(
      sees: [
        AgentView.of(() => surface.items)
            .as('items', 'What is on the shopping list now.', .list(.string)),
      ],
      calls: [
        AgentTool(
          surface.clear,
          name: 'clear',
          description: 'Empties the list.',
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

extension on ShoppingListNotifier {
  List<AgentCapability> get _$agentCapabilities => [
    .seesAs('items', items),
    .callsWithApproval(clear),
  ];
}
