import 'dart:async';

import 'package:tandem/tandem.dart';

final class Shop() implements AgentSurface {
  final _changes = StreamController<Object?>.broadcast();

  /// What is on the shopping list now.
  final items = <String>[];

  Future<void> serverReply = Future.value();

  /// The signals of [changes] wait for it, as with a state library that
  /// reports a change later.
  Future<void> changesArrive = Future.value();

  /// Not listed with `.sees`, like a selected tab.
  int tab = 0;

  int refreshes = 0;

  @override
  Stream<Object?> get changes => _changes.stream;

  /// Whether a session listens to [changes].
  bool get hasSession => _changes.hasListener;

  Future<void> close() => _changes.close();

  /// Makes [agentCapabilities] throw, as a bug in the list would.
  bool listThrows = false;

  @override
  List<AgentCapability> get agentCapabilities {
    if (listThrows) {
      throw StateError('The list is broken.');
    }
    return [
      .sees(items),
      .calls(add),
      .calls(removeAt),
      .calls(refresh),
      if (items.isNotEmpty) .callsWithApproval(clear),
      .callsWithApproval(share),
    ];
  }

  /// Adds [item] to the list.
  void add(String item) {
    if (item.isEmpty) {
      throw const ToolCallRefused('The item must not be empty.');
    }
    items.add(item);
    _changed();
  }

  /// Removes the item at [index].
  void removeAt(int index) {
    // Unchecked, so a bad index throws a RangeError, as a bug would.
    items.removeAt(index);
    _changed();
  }

  /// Empties the list.
  Future<void> clear() async {
    await serverReply;
    items.clear();
    _changed();
  }

  /// Reloads the list from the server.
  Future<void> refresh() async {
    refreshes++;
    await serverReply;
  }

  /// Sends the list to the family.
  Future<void> share() async {
    await serverReply;
  }

  void showTab(int index) {
    tab = index;
    _changed();
  }

  void _changed() {
    final value = [...items];
    unawaited(changesArrive.then((_) => _changes.add(value)));
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
        refresh,
        name: 'refresh',
        description: 'Reloads the list from the server.',
        parameters: {'type': 'object', 'properties': {}},
        invoke: (args) async {
          await refresh();
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
      AgentTool(
        share,
        name: 'share',
        description: 'Sends the list to the family.',
        parameters: {'type': 'object', 'properties': {}},
        invoke: (args) async {
          await share();
          return null;
        },
      ),
    ],
  );
}
