import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  late _Bench bench;
  late List<Map<String, Object?>> bodies;

  setUp(() {
    bench = _Bench();
    addTearDown(bench.close);
    bodies = [];
  });

  Future<TandemSession> draw(
    WidgetTester tester, {
    List<Map<String, Object?>> view = _keepPots,
    TandemApprovals approvals = const .none(),
  }) async {
    late TandemSession session;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: TandemScope.connected(
          surface: (context) => bench,
          connection: ScriptedAgent([
            (body) {
              bodies.add(body);
              return [
                .callTool('tandem_show_view', {'components': jsonEncode(view)}),
                const .say('There it is.'),
              ];
            },
          ]),
          approvals: approvals,
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return const TandemView(catalog: _Controls());
            },
          ),
        ),
      ),
    );
    session.send('Show it');
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('the tool takes the components as a JSON array in a string', (
    tester,
  ) async {
    await draw(tester);

    final tools = switch (bodies.single['tools']) {
      final List<Object?> tools => tools,
      _ => const <Object?>[],
    };
    expect(
      tools,
      contains(
        containsPair('parameters', {
          'type': 'object',
          'properties': {
            'components': {
              'type': 'string',
              'description':
                  'The components of the view as a JSON array, as in the '
                  'example.',
            },
          },
          'required': ['components'],
        }),
      ),
    );
  });

  testWidgets('an action drawn with a value that changed since calls nothing, '
      'also before the screen reports the change', (tester) async {
    await draw(tester);
    final press = tester.widget<_Button>(find.byType(_Button)).onPressed;

    bench
      ..pots = 9
      ..changed();
    press();
    await tester.pumpAndSettle();
    expect(bench.set, isEmpty);

    await tester.tap(find.byType(_Button));
    await tester.pumpAndSettle();
    expect(bench.set, [9]);
  });

  testWidgets('a field whose method needs approval since it was drawn calls '
      'nothing, also before the screen reports the change', (tester) async {
    final session = await draw(
      tester,
      view: _enterPots,
      approvals: const .fromState(),
    );
    final enter = tester.widget<_Field>(find.byType(_Field)).onChanged;

    bench
      ..guarded = true
      ..changed();
    enter(9);
    await tester.pumpAndSettle();

    expect(session.status, isA<Idle>());
    expect(bench.set, isEmpty);
  });

  testWidgets('a view whose screen list throws shows that it is not available, '
      'without a cause', (tester) async {
    await draw(tester);

    bench
      ..listThrows = true
      ..changed();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isStateError);
    expect(find.text('This view is not available now.'), findsOneWidget);
    bench.listThrows = false;
  });
}

const _keepPots = [
  {
    'id': 'root',
    'component': 'Button',
    'onPressed': {
      'action': {
        'event': {
          'name': 'set_pots',
          'context': {
            'pots': {'path': '/pots'},
          },
        },
      },
    },
  },
];

const _enterPots = [
  {
    'id': 'root',
    'component': 'Field',
    'onChanged': {
      'action': {
        'event': {
          'name': 'set_pots',
          'context': {
            'pots': {'input': true},
          },
        },
      },
    },
  },
];

/// A screen with the number of pots and a method that sets it.
final class _Bench() implements AgentSurface {
  final _changes = StreamController<Object?>.broadcast();

  int pots = 2;

  /// Every number [setPots] got.
  final set = <int>[];

  bool listThrows = false;

  /// Whether [setPots] needs approval.
  bool guarded = false;

  @override
  Stream<Object?> get changes => _changes.stream;

  void changed() => _changes.add(null);

  Future<void> close() => _changes.close();

  @override
  List<AgentCapability> get agentCapabilities {
    if (listThrows) throw StateError('The list is broken.');
    return [
      .sees(pots),
      if (guarded) .callsWithApproval(setPots) else .calls(setPots),
    ];
  }

  /// Sets the number of pots.
  void setPots(int pots) {
    set.add(pots);
    this.pots = pots;
  }

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [AgentView.of(() => pots).as('pots', 'The pots.', .integer)],
    calls: [
      AgentTool(
        setPots,
        name: 'set_pots',
        description: 'Sets the number of pots.',
        parameters: const [AgentParameter<int>('pots', .integer)],
        invoke: (args) {
          setPots(args.read('pots'));
          return null;
        },
      ),
    ],
  );
}

/// A button and a field.
final class const _Controls() implements AgentCatalog {
  @override
  List<AgentComponent> get components => [
    AgentComponent<_Button>.of(
      name: 'Button',
      description: 'A button.',
      properties: (property) => [property.press('onPressed')],
      build: (args) => _Button(args.press('onPressed')),
    ),
    AgentComponent<_Field>.of(
      name: 'Field',
      description: 'A field for a number.',
      properties: (property) => [property.field<int>('onChanged').as(.integer)],
      build: (args) => _Field(args.field<int>('onChanged')),
    ),
  ];

  @override
  String get guidelines => 'Draw one control.';

  @override
  List<Map<String, Object?>> get example => _keepPots;
}

final class const _Button(final VoidCallback onPressed)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onPressed, child: const Text('Keep'));
}

final class const _Field(final ValueChanged<int> onChanged)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('Pots');
}
