import 'dart:async';

import 'package:tandem/tandem.dart';

/// The A2UI messages of a view of [components] on Tandem's catalog.
List<Map<String, Object?>> drawing(List<Map<String, Object?>> components) => [
  {
    'version': 'v0.9.1',
    'createSurface': {
      'surfaceId': 'main',
      'catalogId': 'https://pub.dev/packages/tandem/a2ui/v0_9_1/catalog.json',
    },
  },
  {
    'version': 'v0.9.1',
    'updateComponents': {'surfaceId': 'main', 'components': components},
  },
];

/// A button [id] whose action is [event], labelled with its id.
List<Map<String, Object?>> button(String id, Map<String, Object?> event) => [
  {
    'id': id,
    'component': 'Button',
    'child': '${id}_label',
    'action': {'event': event},
  },
  {'id': '${id}_label', 'component': 'Text', 'text': id},
];

/// A view of the `Shop` of the tests with every component of the catalog:
/// each item with a button that adds it again, and a button that shares the
/// list.
final shoppingListView = drawing([
  {'id': 'root', 'component': 'Card', 'child': 'body'},
  {
    'id': 'body',
    'component': 'Column',
    'children': ['title', 'items', 'line', 'share'],
  },
  {
    'id': 'title',
    'component': 'Text',
    'variant': 'h2',
    'text': {
      'call': 'formatString',
      'args': {'value': r'First: ${/items/0}'},
      'returnType': 'string',
    },
  },
  {
    'id': 'items',
    'component': 'List',
    'children': {'componentId': 'item', 'path': '/items'},
  },
  {
    'id': 'item',
    'component': 'Row',
    'children': ['name', 'again'],
  },
  {
    'id': 'name',
    'component': 'Text',
    'text': {'path': '.'},
  },
  ...button('again', {
    'name': 'add',
    'context': {
      'item': {'path': '.'},
    },
  }),
  {'id': 'line', 'component': 'Divider'},
  ...button('share', {'name': 'share'}),
]);

final class ViewData(Map<String, Object?> values) implements AgentSurface {
  var _values = values;
  final _changes = StreamController<Object?>.broadcast();

  void replace(Map<String, Object?> values) {
    _values = values;
    _changes.add(null);
  }

  Future<void> close() => _changes.close();

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  List<AgentCapability> get agentCapabilities => [
    for (final value in _values.values) .sees(value),
  ];

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [
      for (final MapEntry(:key, :value) in _values.entries)
        AgentView.of<Object?>(() => value, key, key, (value) => value),
    ],
    calls: [],
  );
}
