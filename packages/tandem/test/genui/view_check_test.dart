import 'package:a2ui_core/a2ui_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/tandem.dart';

import '../support/shop.dart';
import '../support/views.dart';

void main() {
  late Shop shop;

  setUp(() {
    shop = Shop()..items.addAll(['milk', 'bread']);
    addTearDown(shop.close);
  });

  List<String> problems(List<Map<String, Object?>> components) =>
      ViewCheck(AgentListing.of(shop)).problems(drawing(components));

  test('a view of every component, bound to the screen and its methods, '
      'passes', () {
    expect(
      ViewCheck(AgentListing.of(shop)).problems(shoppingListView),
      isEmpty,
    );
  });

  test('a message that A2UI refuses is the only problem', () {
    expect(
      problems([
        {'id': 'root', 'component': 'TextField', 'label': 'Item'},
        {
          'id': 'orphan',
          'component': 'Text',
          'text': {'path': '/nothing'},
        },
      ]),
      [contains("no component named 'TextField'")],
    );
  });

  test('a view draws one surface, with a root', () {
    final messages = [
      ...drawing([
        {'id': 'root', 'component': 'Divider'},
      ]),
      {
        'version': 'v0.9.1',
        'createSurface': {
          'surfaceId': 'other',
          'catalogId':
              'https://pub.dev/packages/tandem/a2ui/v0_9_1/catalog.json',
        },
      },
    ];

    expect([
      for (final view in [messages, <Map<String, Object?>>[]])
        ViewCheck(AgentListing.of(shop)).problems(view),
    ], everyElement([startsWith('Draw one surface')]));
  });

  test('component accessibility metadata is refused in every supplied '
      'definition, including an overwritten or unused one', () {
    for (final metadata in [
      <String, Object?>{},
      {'label': 'Other name'},
    ]) {
      final messages = [
        ...drawing([
          {'id': 'root', 'component': 'Text', 'text': 'Visible'},
          {'id': 'unused', 'component': 'Divider', 'accessibility': metadata},
        ]),
        drawing([
          {'id': 'unused', 'component': 'Divider'},
        ]).last,
      ];
      expect(ViewCheck(AgentListing.of(shop)).problems(messages), [
        contains('component accessibility metadata is not supported'),
      ]);
      final processor = tandemProcessor();
      addTearDown(processor.dispose);
      expect(
        () => processor.processMessages(messages),
        throwsA(isA<A2uiError>()),
      );
    }

    expect(
      ViewCheck(AgentListing.of(_AccessibilityAction())).problems(
        drawing(
          button('root', {
            'name': 'describe',
            'context': {'accessibility': 'A method argument'},
          }),
        ),
      ),
      isEmpty,
    );
  });

  test('a button calls a method the screen lists now, with its parameters', () {
    shop.items.clear();

    expect(
      problems([
        {
          'id': 'root',
          'component': 'Column',
          'children': ['clear', 'add', 'other'],
        },
        ...button('clear', {'name': 'clear'}),
        ...button('add', {
          'name': 'add',
          'context': {'size': 2},
        }),
        {
          'id': 'other',
          'component': 'Button',
          'child': 'other_label',
          'action': {
            'functionCall': {
              'call': 'formatString',
              'args': {'value': 'x'},
            },
          },
        },
        {'id': 'other_label', 'component': 'Text', 'text': 'Other'},
      ]),
      [
        startsWith('clear must call a method of the screen'),
        'add: add has no parameter size. Parameters: item.',
        'add: add needs item.',
        allOf(
          startsWith('other must call a method of the screen'),
          endsWith('Methods: add, remove_at, refresh, share.'),
        ),
      ],
    );
  });

  test('a path must find the screen data, inside a list from its first item; '
      'in an empty list nothing can be told wrong', () {
    final view = [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['title', 'items', 'tabs'],
      },
      {
        'id': 'title',
        'component': 'Text',
        'text': {
          'call': 'formatString',
          'args': {'value': r'${/items/0} and ${/basket/0}'},
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
        'component': 'Text',
        'text': {'path': 'name'},
      },
      {
        'id': 'tabs',
        'component': 'List',
        'children': {'componentId': 'tab', 'path': '/tabs'},
      },
      {'id': 'tab', 'component': 'Text', 'text': 'Tab'},
    ];

    expect(problems(view), [
      'title: the path /basket/0 is not in the screen data.',
      'item: the path name is not in the screen data.',
      'tabs: the path /tabs is not a list in the screen data.',
    ]);
    shop.items.clear();
    expect(problems(view), [
      'title: the path /items/0 is not in the screen data.',
      'title: the path /basket/0 is not in the screen data.',
      'tabs: the path /tabs is not a list in the screen data.',
    ]);
  });

  test(r'a path in a ${...} is read as A2UI reads it', () {
    expect(
      problems([
        {
          'id': 'root',
          'component': 'Text',
          'text': {
            'call': 'formatString',
            'args': {'value': r'${ /items/0 } ${ /basket/0 } \${/nothing}'},
            'returnType': 'string',
          },
        },
      ]),
      ['root: the path /basket/0 is not in the screen data.'],
    );
  });

  test('a view that draws too many components is the only problem, even '
      'when a few components draw it', () {
    // Each column draws the next one twice, so 26 components draw 2^25.
    final columns = [
      for (var i = 0; i < 25; i++)
        {
          'id': i == 0 ? 'root' : 'column$i',
          'component': 'Column',
          'children': ['column${i + 1}', 'column${i + 1}'],
        },
      {
        'id': 'column25',
        'component': 'Text',
        'text': {'path': '/nothing'},
      },
    ];

    const tooMany =
        'The view draws more than ${ViewCheck.maxComponents} components, '
        'counting one for every place a component is drawn. Draw fewer.';
    expect(problems(columns), [tooMany]);
  });
}

final class _AccessibilityAction() implements AgentSurface {
  void describe(String accessibility) {}

  @override
  List<AgentCapability> get agentCapabilities => [.calls(describe)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [],
    calls: [
      AgentTool(
        describe,
        name: 'describe',
        description: 'Describes accessibility.',
        parameters: {
          'type': 'object',
          'properties': {
            'accessibility': {'type': 'string'},
          },
          'required': ['accessibility'],
        },
        invoke: (args) => describe(args.read('accessibility')),
      ),
    ],
  );
}
