import 'dart:async';

import 'package:tandem/tandem.dart';

/// A shopping list with a hand-written agent schema, shaped like the code
/// `tandem_generator` writes.
final class Shop() implements AgentSurface {
  final _changes = StreamController<Object?>.broadcast();

  /// What is on the shopping list now.
  final items = <String>[];

  /// Emits after every change of [items].
  Stream<Object?> get changes => _changes.stream;

  /// Closes [changes]. Dispose the session that listens to it first.
  Future<void> close() => _changes.close();

  @override
  List<AgentCapability> get agent => [
    .sees(items),
    .calls(add),
    if (items.isNotEmpty) .callsWithApproval(clear),
  ];

  /// Adds [item] to the list.
  void add(String item) {
    if (item.isEmpty) {
      throw ArgumentError.value(item, 'item', 'must not be empty');
    }
    items.add(item);
    _changes.add([...items]);
  }

  /// Empties the list.
  void clear() {
    items.clear();
    _changes.add([...items]);
  }

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [
      AgentView.of(
        () => items,
        'items',
        'What is on the shopping list now.',
        (items) => items,
      ),
    ],
    calls: [
      AgentTool(
        add,
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
          add(args.read('item'));
          return null;
        },
      ),
      AgentTool(
        clear,
        name: 'clear',
        description: 'Empties the list.',
        parameters: {'type': 'object', 'properties': {}},
        invoke: (args) {
          clear();
          return null;
        },
      ),
    ],
  );
}
