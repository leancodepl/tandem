import 'dart:async';

import 'package:tandem/tandem.dart';

/// A shopping list with a hand-written agent schema, shaped like the code
/// `tandem_generator` writes.
final class Shop() implements AgentSurface {
  final _changes = StreamController<Object?>.broadcast();

  final items = <String>[];

  /// [clear] waits for this first, as a call to a server would.
  Future<void> serverReply = Future.value();

  Stream<Object?> get changes => _changes.stream;

  /// Dispose the session that listens to [changes] first.
  Future<void> close() => _changes.close();

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(items),
    .calls(add),
    .calls(removeAt),
    if (items.isNotEmpty) .callsWithApproval(clear),
  ];

  void add(String item) {
    if (item.isEmpty) {
      throw ArgumentError.value(item, 'item', 'must not be empty');
    }
    items.add(item);
    _changes.add([...items]);
  }

  void removeAt(int index) {
    // Unchecked, so a bad index throws a RangeError, as a bug would.
    items.removeAt(index);
    _changes.add([...items]);
  }

  Future<void> clear() async {
    await serverReply;
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
        removeAt,
        name: 'remove_at',
        description: 'Removes the item at [index].',
        parameters: {
          'type': 'object',
          'properties': {
            'index': {'type': 'integer'},
          },
          'required': ['index'],
        },
        invoke: (args) {
          removeAt(args.read('index'));
          return null;
        },
      ),
      AgentTool(
        clear,
        name: 'clear',
        description: 'Empties the list.',
        parameters: {'type': 'object', 'properties': {}},
        invoke: (args) async {
          await clear();
          return null;
        },
      ),
    ],
  );
}
