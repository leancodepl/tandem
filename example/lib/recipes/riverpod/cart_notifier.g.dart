// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_notifier.dart';

// **************************************************************************
// AgentGenerator
// **************************************************************************

mixin _$CartNotifier implements AgentSurface {
  @override
  AgentSchema get agentSchema {
    final surface = this as CartNotifier;

    return AgentSchema(
      sees: [
        AgentView.of(
          () => surface.items,
          'items',
          'What is in the cart now.',
          (items) => items,
        ),
      ],
      calls: [
        AgentTool(
          surface.add,
          name: 'add',
          description: 'Puts [item] in the cart.',
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
          description: 'Takes [item] out of the cart.',
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
          surface.checkout,
          name: 'checkout',
          description: 'Orders everything in the cart and empties it.',
          parameters: const {'type': 'object', 'properties': {}},
          invoke: (args) {
            surface.checkout();
            return null;
          },
        ),
      ],
    );
  }
}
