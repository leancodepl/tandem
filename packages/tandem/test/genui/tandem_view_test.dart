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
    List<AgentTurn> after = const [],
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
            for (final turn in after)
              (body) {
                bodies.add(body);
                return turn(body);
              },
          ]),
          approvals: approvals,
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return TandemView(catalog: _Controls());
            },
          ),
        ),
      ),
    );
    session.send('Show it');
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('the tool takes the components as a JSON array in a string, '
      'and its description names each method as the agent calls it', (
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
        containsPair(
          'parameters',
          allOf(
            containsPair('properties', {
              'components': containsPair('type', 'string'),
            }),
            containsPair('required', ['components']),
          ),
        ),
      ),
    );
    expect(
      tools,
      contains(
        allOf(
          containsPair('name', 'tandem_show_view'),
          containsPair(
            'description',
            contains('\n- set_pots(pots: integer)\n'),
          ),
        ),
      ),
    );
  });

  testWidgets('a view stays when a rebuild brings another instance of its '
      'catalog', (tester) async {
    await draw(tester);

    expect(find.byType(_Button), findsOneWidget);
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

  testWidgets('the latest entry of a field made while its method runs goes '
      'once the method returned', (tester) async {
    await draw(tester, view: _enterPots);
    final hold = bench.hold = Completer<void>();
    void enter(int pots) =>
        tester.widget<_Field>(find.byType(_Field)).onChanged(pots);

    enter(3);
    await tester.pump();
    enter(5);
    enter(7);
    bench.hold = null;
    hold.complete();
    await tester.pumpAndSettle();

    expect(bench.set, [3, 7]);
  });

  testWidgets('a view whose screen list throws shows that it is not available, '
      'without a cause', (tester) async {
    await draw(tester);

    bench
      ..listThrows = (() => true)
      ..changed();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isStateError);
    expect(find.text('This view is not available now.'), findsOneWidget);
    bench.listThrows = () => false;
  });

  testWidgets('a view drawn while the screen list throws fails its call, not '
      'the run', (tester) async {
    final session = await draw(
      tester,
      after: [
        (_) => [
          .callTool('tandem_show_view', {'components': jsonEncode(_keepPots)}),
        ],
        (_) => const [.say('I cannot draw it now.')],
      ],
    );
    bench.listThrows = () => switch (session.status) {
      Thinking(drawing: true) => true,
      _ => false,
    };

    final reported = <FlutterErrorDetails>[];
    final onError = FlutterError.onError;
    FlutterError.onError = reported.add;
    session.send('Show it again');
    await tester.pumpAndSettle();
    FlutterError.onError = onError;

    expect(reported, isNotEmpty);
    expect(
      AgentRequest(bodies.last).latestToolResults.single.value,
      containsPair('status', 'failed'),
    );
    expect(session.items.whereType<ChatNotice>(), isEmpty);
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

  bool Function() listThrows = () => false;

  /// Whether [setPots] needs approval.
  bool guarded = false;

  /// What [setPots] waits for before it returns, if anything.
  Completer<void>? hold;

  @override
  Stream<Object?> get changes => _changes.stream;

  void changed() => _changes.add(null);

  Future<void> close() => _changes.close();

  @override
  List<AgentCapability> get agentCapabilities {
    if (listThrows()) throw StateError('The list is broken.');
    return [
      .sees(pots),
      if (guarded) .callsWithApproval(setPots) else .calls(setPots),
    ];
  }

  /// Sets the number of pots.
  Future<void> setPots(int pots) async {
    set.add(pots);
    this.pots = pots;
    await hold?.future;
  }

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [AgentView.of(() => pots).as('pots', 'The pots.', .integer)],
    calls: [
      AgentTool(
        setPots,
        name: _BenchTool.setPots,
        description: 'Sets the number of pots.',
        parameters: const [AgentParameter<int>('pots', .integer)],
        invoke: (args) async {
          await setPots(args.read('pots'));
          return null;
        },
      ),
    ],
  );
}

/// A button and a field. Not const, so every build makes another instance.
final class _Controls() implements AgentCatalog {
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

enum _BenchTool(@override final String value) implements ToolName {
  setPots('set_pots'),
}
