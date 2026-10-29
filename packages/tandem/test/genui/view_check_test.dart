import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/genui/view_description.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('a field whose entry holds objects at any depth is refused for a '
      'parameter read by path, and passes into one the agent writes', () {
    final AgentType<_Node> node = .object(
      id: 'test#Node',
      fields: (field) => [field('name', (node) => node.name).as(.string)],
      build: (values) => _Node(values('name')),
    );
    List<String> problemsOf<T>(AgentType<T> entry, {bool input = false}) =>
        _problemsOf(entry, entry, input: input);

    expect(problemsOf(AgentType.string), isEmpty);
    expect(problemsOf<List<_Node>>(.list(node), input: true), isEmpty);
    expect(problemsOf(node, input: true), isEmpty);
    String byPath(String entry) =>
        'root.onPick.picked: the field enters a $entry, whose objects picked '
        'takes only by path.';
    expect(problemsOf(node), [byPath('Node')]);
    expect(problemsOf<List<List<_Node>>>(.list(.list(node))), [
      byPath('Node[][]'),
    ]);
  });

  test('a field that may enter null is refused for a parameter that takes '
      'no null', () {
    expect(_problemsOf(.nullable(AgentType.string), AgentType.string), [
      'root.onPick.picked: the field enters a string?, not a string.',
    ]);
    expect(
      _problemsOf(.nullable(AgentType.string), .nullable(AgentType.string)),
      isEmpty,
    );
    expect(_problemsOf(AgentType.string, .nullable(AgentType.string)), isEmpty);
  });

  test('a property of a class with a converter takes only a path, and one of '
      "a value with a converter takes the converter's form", () {
    final AgentType<_Node> grower = .converted(
      const _NodeConverter(),
      AgentType.string,
      id: 'test#Grower',
      converterId: 'test#NodeConverter()',
      object: true,
    );
    final AgentType<_Node> ink = .converted(
      const _NodeConverter(),
      AgentType.string,
      id: 'test#Ink',
      converterId: 'test#NodeConverter()',
    );
    final check = ViewCheck(_Card(grower: grower, ink: ink), (
      roots: {'growers': .list(grower)},
      methods: const {},
    ));
    List<String> problemsOf(Object? grower) => check.check([
      {'id': 'root', 'component': 'Card', 'grower': grower, 'ink': 'warm'},
    ]).problems;

    const literal =
        'root.grower: write a path to a Grower the screen lists, such as '
        '/growers/<i>, not an object.';
    expect(problemsOf('ana'), [literal]);
    expect(problemsOf({'path': '/growers/0'}), isEmpty);
  });

  test('the description lists a class with a converter by its form, and one '
      'without by its fields', () {
    final AgentType<_Node> grower = .converted(
      const _NodeConverter(),
      AgentType.string,
      id: 'test#Grower',
      converterId: 'test#NodeConverter()',
      description: 'A grower by code.',
      object: true,
    );
    final AgentType<_Node> ink = .converted(
      const _NodeConverter(),
      AgentType.string,
      id: 'test#Ink',
      converterId: 'test#NodeConverter()',
      description: 'An ink by name.',
    );
    final AgentType<_Node> node = .object(
      id: 'test#Node',
      fields: (field) => [field('name', (node) => node.name).as(.string)],
      build: (values) => _Node(values('name')),
    );

    final description = viewDescription(
      _Card(grower: grower, ink: ink),
      AgentListing.of(_Nursery(grower: grower, node: node)),
    );

    expect(
      description,
      allOf(
        contains('- Card: "grower" (Grower, by path), "ink" (Ink).'),
        contains(
          'Forms:\n- Grower: string. A grower by code.\n'
          '- Ink: string. An ink by name.\n',
        ),
        contains('Classes:\n- Node: {name: string}\n'),
      ),
    );
  });

  test('the description and a refusal tell apart two types of one name', () {
    final AgentType<_First> first = .enumeration(
      _First.values,
      id: 'package:first/status.dart#Status',
    );
    final AgentType<_Second> second = .enumeration(
      _Second.values,
      id: 'package:second/status.dart#Status',
    );

    final description = viewDescription(
      _Shelf({'status': first, 'states': .list(second)}),
      AgentListing.of(const _Empty()),
    );

    expect(
      description,
      allOf(
        contains(
          '- Shelf: "status" (first/status.dart#Status), '
          '"states" (second/status.dart#Status[]).',
        ),
        contains(
          'Names (write one):\n'
          '- first/status.dart#Status: pending | accepted\n'
          '- second/status.dart#Status: draft | sent\n',
        ),
      ),
    );
    const refusal =
        'root.onPick.picked: the field enters a first/status.dart#Status, not '
        'a second/status.dart#Status.';
    expect(_problemsOf(first, second), [refusal]);
  });

  test('the description gives the form of a converted type with the names '
      'and fields it takes', () {
    final AgentType<_First> status = .enumeration(
      _First.values,
      id: 'test#Status',
    );
    final AgentType<_Node> code = .object(
      id: 'test#Code',
      fields: (field) => [field('name', (node) => node.name).as(.string)],
      build: (values) => _Node(values('name')),
    );
    final AgentType<_Node> ink = .converted(
      const _InkConverter(),
      status,
      id: 'test#Ink',
      converterId: 'test#InkConverter()',
      description: 'The ink of a note.',
    );
    final AgentType<_Node> stamp = .converted(
      const _StampConverter(),
      code,
      id: 'test#Stamp',
      converterId: 'test#StampConverter()',
    );

    final description = viewDescription(
      _Shelf({'ink': ink, 'stamp': stamp}),
      AgentListing.of(const _Empty()),
    );

    expect(
      description,
      allOf(
        contains('Names (write one):\n- Status: pending | accepted\n'),
        contains('Forms:\n- Ink: Status. The ink of a note.\n- Stamp: Code.\n'),
        contains('Classes:\n- Code: {name: string}\n'),
      ),
    );
  });
}

/// What the check finds in a view of one [_Picker] whose field enters a
/// value of [entry] into a parameter of [parameter].
List<String> _problemsOf<T>(
  AgentType<T> entry,
  AgentType<Object?> parameter, {
  bool input = false,
}) {
  final pick = AgentTool(
    _pick,
    name: 'pick',
    description: 'Picks what the user entered.',
    parameters: [AgentParameter('picked', parameter, input: input)],
    invoke: (_) => null,
  );
  final check = ViewCheck(_Picker(entry), (
    roots: const {},
    methods: {'pick': (tool: pick, needsApproval: false)},
  ));
  final (:problems, view: _) = check.check([
    {
      'id': 'root',
      'component': 'Picker',
      'onPick': {
        'action': {
          'event': {
            'name': 'pick',
            'context': {
              'picked': {'input': true},
            },
          },
        },
      },
    },
  ]);
  return problems;
}

void _pick(Object? picked) {}

final class _Node(final String name);

/// One widget whose field enters a value of [_entry].
final class _Picker<T>(final AgentType<T> _entry) implements AgentCatalog {
  @override
  List<AgentComponent> get components => [
    AgentComponent<SizedBox>.of(
      name: 'Picker',
      description: 'Picks a value.',
      properties: (property) => [property.field<T>('onPick').as(_entry)],
      build: (args) => const SizedBox(),
    ),
  ];

  @override
  String get guidelines => 'Draw one picker.';

  @override
  List<Map<String, Object?>> get example => const [];
}

final class const _NodeConverter() implements JsonConverter<_Node, String> {
  @override
  _Node fromJson(String json) => _Node(json);

  @override
  String toJson(_Node object) => object.name;
}

/// One card with a grower and a ink, both through a converter.
final class _Card({
  required final AgentType<_Node> grower,
  required final AgentType<_Node> ink,
}) implements AgentCatalog {
  @override
  List<AgentComponent> get components => [
    AgentComponent<SizedBox>.of(
      name: 'Card',
      description: 'Shows a grower in an ink.',
      properties: (property) => [
        property<_Node>('grower').value(grower),
        property<_Node>('ink').value(ink),
      ],
      build: (args) => const SizedBox(),
    ),
  ];

  @override
  String get guidelines => 'Draw one card.';

  @override
  List<Map<String, Object?>> get example => const [];
}

/// A screen that lists growers and nodes.
final class _Nursery({
  required final AgentType<_Node> grower,
  required final AgentType<_Node> node,
}) implements AgentSurface {
  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(const <_Node>[]),
    .sees(const <_Node>[]),
  ];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [
      AgentView.of(() => const <_Node>[])
          .as('growers', 'The growers.', .list(grower)),
      AgentView.of(() => const <_Node>[])
          .as('nodes', 'The nodes.', .list(node)),
    ],
    calls: const [],
  );
}

enum _First() {
  pending,
  accepted,
}

enum _Second() {
  draft,
  sent,
}

final class const _InkConverter() implements JsonConverter<_Node, _First> {
  @override
  _Node fromJson(_First json) => _Node(json.name);

  @override
  _First toJson(_Node object) => _First.values.byName(object.name);
}

final class const _StampConverter() implements JsonConverter<_Node, _Node> {
  @override
  _Node fromJson(_Node json) => json;

  @override
  _Node toJson(_Node object) => object;
}

/// One widget with a value property of each type in [_properties].
final class const _Shelf(final Map<String, AgentType<Object?>> _properties)
    implements AgentCatalog {
  @override
  List<AgentComponent> get components => [
    AgentComponent<SizedBox>.of(
      name: 'Shelf',
      description: 'Shows values.',
      properties: (property) => [
        for (final MapEntry(key: name, value: type) in _properties.entries)
          property<Object?>(name).value(type),
      ],
      build: (args) => const SizedBox(),
    ),
  ];

  @override
  String get guidelines => 'Draw one shelf.';

  @override
  List<Map<String, Object?>> get example => const [];
}

/// A screen that shows the agent nothing.
final class const _Empty() implements AgentSurface {
  @override
  List<AgentCapability> get agentCapabilities => const [];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => const AgentSchema(sees: [], calls: []);
}
