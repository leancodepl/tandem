import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/view_check.dart';

import '../support/shop.dart';

void main() {
  List<String> problems(List<Object?> messages) {
    final shop = Shop()..items.add('milk');
    addTearDown(shop.close);
    return ViewCheck(AgentListing.of(shop)).problems(messages);
  }

  test('a view of the screen data with its methods passes', () {
    expect(
      problems(
        _view([
          {
            'id': 'root',
            'component': 'Column',
            'children': ['title', 'items', 'share'],
          },
          {
            'id': 'title',
            'component': 'Text',
            'text': {
              'call': 'formatString',
              'args': {'value': r'First: ${/items/0}'},
              'returnType': 'string',
            },
            'variant': 'h2',
          },
          {
            'id': 'items',
            'component': 'List',
            'children': {'componentId': 'item', 'path': '/items'},
          },
          {'id': 'item', 'component': 'Card', 'child': 'remove'},
          ..._button('remove', {
            'name': 'add',
            'context': {
              'item': {'path': '.'},
            },
          }),
          ..._button('share', {'name': 'share'}),
        ]),
      ),
      isEmpty,
    );
  });

  test('a message of another version is refused', () {
    final [create, update] = _view([_text]);
    expect(problems([create, update..['version'] = 'v0.9']), [
      contains('"version": "v0.9.1"'),
    ]);
  });

  test('updateDataModel is refused, screen data comes from .sees', () {
    expect(
      problems([
        ..._view([_text]),
        _message('updateDataModel', {
          'path': '/items',
          'value': ['fake'],
        }),
      ]),
      [contains('updateDataModel')],
    );
  });

  test('a component or property outside the catalog is refused', () {
    expect(
      problems(
        _view([
          {'id': 'root', 'component': 'Image', 'url': 'https://example.com'},
        ]),
      ),
      [contains('Image')],
    );
    expect(
      problems(
        _view([
          {'id': 'root', 'component': 'Text', 'text': 'Hi', 'color': 'red'},
        ]),
      ),
      [contains('root')],
    );
  });

  test('a function other than formatString and a functionCall action are '
      'refused', () {
    expect(
      problems(
        _view([
          {
            'id': 'root',
            'component': 'Text',
            'text': {'call': 'openUrl', 'args': <String, Object?>{}},
          },
          ..._button('pay', null, action: {'functionCall': 'openUrl'}),
        ]),
      ),
      [contains('openUrl, not allowed'), contains('functionCall')],
    );
  });

  test('a button for a method the screen does not list is refused with the '
      'methods', () {
    expect(problems(_view(_button('root', {'name': 'pay'}))), [
      allOf(contains('pay'), contains('add, remove_at, refresh, clear, share')),
    ]);
  });

  test('a button whose arguments do not fit the method is refused', () {
    expect(
      problems(
        _view([
          {
            'id': 'root',
            'component': 'Row',
            'children': ['wrong', 'missing'],
          },
          ..._button('wrong', {
            'name': 'add',
            'context': {'thing': 'eggs', 'item': 'eggs'},
          }),
          ..._button('missing', {'name': 'add'}),
        ]),
      ),
      [contains('no parameter thing'), contains('add needs item')],
    );
  });

  test('a path outside the screen data is refused', () {
    expect(
      problems(
        _view([
          {
            'id': 'root',
            'component': 'Text',
            'text': {'path': '/items[0]'},
          },
        ]),
      ),
      [contains('/items[0]')],
    );
  });
}

const _text = {'id': 'root', 'component': 'Text', 'text': 'Hi'};

Map<String, Object?> _message(String kind, Map<String, Object?> body) => {
  'version': 'v0.9.1',
  kind: {'surfaceId': 'main', ...body},
};

List<Map<String, Object?>> _view(List<Map<String, Object?>> components) => [
  _message('createSurface', {'catalogId': tandemCatalogId}),
  _message('updateComponents', {'components': components}),
];

List<Map<String, Object?>> _button(
  String id,
  Map<String, Object?>? event, {
  Map<String, Object?>? action,
}) => [
  {
    'id': id,
    'component': 'Button',
    'child': '${id}_label',
    'action': action ?? {'event': event},
  },
  {'id': '${id}_label', 'component': 'Text', 'text': id},
];
