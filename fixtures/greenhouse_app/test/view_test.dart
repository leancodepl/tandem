import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/browse_cubit.dart';
import 'package:greenhouse_app/contracts.dart';
import 'package:greenhouse_app/greenhouse_catalog.dart';
import 'package:greenhouse_app/look_cubit.dart';
import 'package:greenhouse_app/paint_cubit.dart';
import 'package:greenhouse_app/plant_widgets.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:kit_ds/kit_ds.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  late BrowseCubit browse;
  final bodies = <Map<String, Object?>>[];

  setUp(() {
    browse = BrowseCubit([_plant('a'), _plant('b')]);
    bodies.clear();
  });

  Future<TandemSession> draw(
    WidgetTester tester,
    List<Map<String, Object?>> components, {
    AgentSurface? surface,
    AgentCatalog catalog = const GreenhouseCatalog(),
    TandemApprovals approvals = const .fromState(),
    bool withView = true,
    List<AgentTurn> after = const [],
    void Function(TandemEvent event, TandemSession session)? onEvent,
  }) async {
    late TandemSession session;
    AgentTurn record(AgentTurn turn) => (body) {
      bodies.add(body);
      return turn(body);
    };
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: TandemScope.connected(
          surface: (context) => surface ?? browse,
          connection: ScriptedAgent([
            record((_) => [_show(components), const .say('There it is.')]),
            for (final turn in after) record(turn),
          ]),
          approvals: approvals,
          onEvent: (context, event, session) => onEvent?.call(event, session),
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return SingleChildScrollView(
                child: withView
                    ? TandemView(
                        catalog: catalog,
                        whenUnavailable: (context) => const Text('Too large'),
                      )
                    : const SizedBox(),
              );
            },
          ),
        ),
      ),
    );
    session.send('Show it');
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('a row gets the very plant of the screen, a tap picks it, and '
      'a meter keeps its default gauge', (tester) async {
    await draw(tester, const GreenhouseCatalog().example);

    expect(find.byType(PlantRow), findsNWidgets(2));
    expect(
      tester.widget<PlantRow>(find.byType(PlantRow).last).plant,
      same(browse.plants[1]),
    );
    expect(tester.widget<PotMeter>(find.byType(PotMeter)).gauge, Gauge.dots);
    await tester.tap(find.text('Fern b'));
    await tester.pumpAndSettle();
    expect(browse.picked, same(browse.plants[1]));
  });

  testWidgets('a tap drawn before the list was reordered opens nothing', (
    tester,
  ) async {
    await draw(tester, const GreenhouseCatalog().example);
    final staleTap = tester
        .widget<PlantRow>(find.byType(PlantRow).first)
        .onPick;

    browse.setPlants([...browse.plants.reversed]);
    await tester.pumpAndSettle();
    staleTap();
    await tester.pumpAndSettle();
    expect(browse.picked, isNull);

    await tester.tap(find.text('Fern b'));
    await tester.pumpAndSettle();
    expect(browse.picked, same(browse.plants.first));
  });

  testWidgets('a row leaves the view without its required action, and a bar '
      'only its undo button without the optional one', (tester) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': ['undo', 'rows'],
      },
      {
        'id': 'undo',
        'component': 'UndoBar',
        'message': 'Picked',
        'onUndo': _action('put_back_plant', {
          'plant': {'path': '/plants/0'},
        }),
      },
      {
        'id': 'rows',
        'component': 'KitStack',
        'children': {'componentId': 'row', 'path': '/plants'},
      },
      {
        'id': 'row',
        'component': 'PlantRow',
        'plant': {'path': ''},
        'onPick': _action('pick', {
          'plant': {'path': ''},
        }),
      },
    ]);
    expect(find.text('Undo'), findsOneWidget);

    browse
      ..canPutBack = false
      ..changed();
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(find.byType(UndoBar), findsOneWidget);
    expect(find.byType(PlantRow), findsNWidgets(2));

    browse
      ..canPick = false
      ..changed();
    await tester.pumpAndSettle();
    expect(find.byType(PlantRow), findsNothing);

    browse
      ..canPick = true
      ..changed();
    await tester.pumpAndSettle();
    expect(find.byType(PlantRow), findsNWidgets(2));
  });

  testWidgets('a field sets the pots through the method, and an action '
      'that needs approval waits for the user, one at a time', (tester) async {
    final events = <TandemEvent>[];
    final session = await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': ['pots', 'compost'],
      },
      {
        'id': 'pots',
        'component': 'PotsField',
        'pots': {'path': '/wanted'},
        'onPots': _action('set_pots', {
          'pots': {'input': true},
        }),
      },
      {
        'id': 'compost',
        'component': 'KitButton',
        'label': 'Compost',
        'onPressed': _action('compost', {
          'plant': {'path': '/plants/0'},
        }),
      },
    ], onEvent: (event, _) => events.add(event));

    await tester.tap(find.text('2 pots'));
    await tester.pumpAndSettle();
    expect(find.text('3 pots'), findsOneWidget);
    expect(events.whereType<AgentCall>().single.caller, Caller.view);

    await tester.tap(find.text('Compost'));
    await tester.pumpAndSettle();
    final request = switch (session.status) {
      AwaitingApproval(:final request) => request,
      final status => throw StateError('Expected an approval, got $status.'),
    };
    expect(request.caller, Caller.view);
    expect(tester.widget<PotsField>(find.byType(PotsField)).onPots, isNull);

    session.approve(request);
    await tester.pumpAndSettle();
    expect(browse.composted, ['a']);
    expect(tester.widget<PotsField>(find.byType(PotsField)).onPots, isNotNull);
  });

  testWidgets('a nested list past 500 components makes the view and its '
      'actions unavailable until it fits again', (tester) async {
    browse.setShelves([_shelf(0, items: 2)]);
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': ['more', 'shelves'],
      },
      {
        'id': 'more',
        'component': 'KitButton',
        'label': 'More pots',
        'onPressed': _action('set_pots', {'pots': 9}),
      },
      {
        'id': 'shelves',
        'component': 'KitStack',
        'children': {'componentId': 'shelf', 'path': '/shelves'},
      },
      {
        'id': 'shelf',
        'component': 'KitStack',
        'children': {'componentId': 'item', 'path': 'items'},
      },
      {
        'id': 'item',
        'component': 'KitText',
        'value': {'path': ''},
        'style': 'plain',
      },
    ]);
    final staleTap = tester.widget<KitButton>(find.byType(KitButton)).onPressed;
    expect(find.text('item 0.1'), findsOneWidget);

    browse.setShelves([for (var i = 0; i < 30; i++) _shelf(i, items: 20)]);
    await tester.pumpAndSettle();
    staleTap?.call();
    await tester.pumpAndSettle();
    expect(find.text('Too large'), findsOneWidget);
    expect(browse.pots, 2);

    browse.setShelves([_shelf(0, items: 2)]);
    await tester.pumpAndSettle();
    expect(find.text('item 0.1'), findsOneWidget);
  });

  testWidgets('a view of exactly 500 components draws, and one more makes it '
      'unavailable', (tester) async {
    // The root, its button and the column of shelves, then 7 shelves of 70
    // items: 3 + 7 + 490 components.
    browse.setShelves([for (var i = 0; i < 7; i++) _shelf(i, items: 70)]);
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': ['more', 'shelves'],
      },
      {
        'id': 'more',
        'component': 'KitButton',
        'label': 'More pots',
        'onPressed': _action('set_pots', {'pots': 9}),
      },
      {
        'id': 'shelves',
        'component': 'KitStack',
        'children': {'componentId': 'shelf', 'path': '/shelves'},
      },
      {
        'id': 'shelf',
        'component': 'KitStack',
        'children': {'componentId': 'item', 'path': 'items'},
      },
      {
        'id': 'item',
        'component': 'KitText',
        'value': {'path': ''},
        'style': 'plain',
      },
    ]);
    expect(find.text('Too large'), findsNothing);
    expect(find.byType(KitText), findsNWidgets(490));

    browse.setShelves([
      for (var i = 0; i < 7; i++) _shelf(i, items: i == 0 ? 71 : 70),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Too large'), findsOneWidget);
  });

  testWidgets('a change of the data builds the catalog as often for 490 items '
      'as for one', (tester) async {
    final catalog = _CountingCatalog();
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': {'componentId': 'shelf', 'path': '/shelves'},
      },
      {
        'id': 'shelf',
        'component': 'KitStack',
        'children': {'componentId': 'item', 'path': 'items'},
      },
      {
        'id': 'item',
        'component': 'KitText',
        'value': {'path': ''},
        'style': 'plain',
      },
    ], catalog: catalog);
    Future<int> readsFor(List<Shelf> shelves) async {
      final before = catalog.reads;
      browse.setShelves(shelves);
      await tester.pumpAndSettle();
      return catalog.reads - before;
    }

    final few = await readsFor([_shelf(0, items: 1)]);
    final many = await readsFor([
      for (var i = 0; i < 7; i++) _shelf(i, items: 70),
    ]);
    expect(find.byType(KitText), findsNWidgets(490));
    expect(many, few);
  });

  testWidgets('a refused view says what to fix, one line each, and the view '
      'before it stays', (tester) async {
    await draw(
      tester,
      const GreenhouseCatalog().example,
      after: [
        (_) => [
          const .say('Here it is as a list.'),
          _show([
            {
              'id': 'root',
              'component': 'KitStack',
              'children': ['title', 'row'],
            },
            {
              'id': 'title',
              'component': 'KitText',
              'style': 'plain',
              'value': {'path': '/plants/0/price'},
              'size': 12,
            },
            {
              'id': 'row',
              'component': 'PlantRow',
              'plant': {'sku': 'x', 'label': 'Made up'},
              'onPick': _action('pick', {
                'plant': {'path': '/plants/0'},
              }),
            },
          ]),
        ],
        (_) => const [.say('Sorry.')],
      ],
    ).then((session) async {
      session.send('Show it as a list');
      await tester.pumpAndSettle();
    });

    final refusal = AgentRequest(bodies.last).latestToolResults.single.value;
    expect(refusal, {
      'status': 'refused',
      'reason':
          'title: KitText has no "size". Properties: style, value, align.\n'
          'title.value: /plants/0/price is not in the data. Paths under '
          '/plants/0: sku, label, light, sizes, pottedOn, careSheet.\n'
          'row.plant: write a path to a PlantDTO the screen lists, such as '
          '/plants/<i>, not an object.',
    });
    expect(find.byType(PlantRow), findsNWidgets(2));
  });

  testWidgets('three refused views in a row withhold the tool until the user '
      'writes again', (tester) async {
    const broken = [
      {'id': 'root', 'component': 'Carousel'},
    ];
    final session = await draw(
      tester,
      broken,
      after: [
        (_) => [_show(broken)],
        (_) => [_show(broken)],
        (_) => const [.say('I will answer in text.')],
        (_) => const [.say('Hi.')],
      ],
    );
    List<Object?> tools(Map<String, Object?> body) => _toolNames(body);

    expect(bodies, hasLength(4));
    expect(tools(bodies[3]), isNot(contains('tandem_show_view')));
    expect(
      AgentRequest(bodies[3]).latestToolResults.single.value,
      containsPair('reason', contains('Answer the user in text.')),
    );

    session.send('Show it again');
    await tester.pumpAndSettle();
    expect(tools(bodies[4]), contains('tandem_show_view'));
  });

  testWidgets('a catalog and a screen that write Color differently stop the '
      'view', (tester) async {
    await draw(
      tester,
      const KitCatalog().example,
      surface: PaintCubit(),
      catalog: const KitCatalog(),
    );

    expect(tester.takeException(), isA<StateError>());
    expect(_toolNames(bodies.first), isNot(contains('tandem_show_view')));
  });

  testWidgets("a converter's bug is reported: the example's in debug, a "
      "view's fails the call, a drawn component's leaves it out", (
    tester,
  ) async {
    _ShadeConverter.bugs.add('grey');
    addTearDown(_ShadeConverter.bugs.clear);
    final session = await draw(
      tester,
      _shade('dark'),
      catalog: const _ShadeCatalog(),
      after: [
        (_) => [_show(_shade('grey'))],
        (_) => const [.say('Sorry.')],
      ],
    );
    expect(tester.takeException(), isStateError);
    expect(find.text('dark'), findsOneWidget);

    session.send('Show grey');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(
      AgentRequest(bodies.last).latestToolResults.single.value,
      containsPair('status', 'failed'),
    );
    expect(find.text('dark'), findsOneWidget);

    _ShadeConverter.bugs.add('dark');
    browse.changed();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(find.text('dark'), findsNothing);
  });

  testWidgets("a catalog's Page<String?> and a screen's Page<String> are two "
      'types, not a conflict', (tester) async {
    await draw(tester, const GreenhouseCatalog().example);

    expect(tester.takeException(), isNull);
    expect(_toolNames(bodies.first), contains('tandem_show_view'));
  });

  testWidgets('a comparison gets the very list of plants by one path, and the '
      'rule of a note, which has no form, stays null', (tester) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': ['note', 'both'],
      },
      {'id': 'note', 'component': 'KitNote', 'body': 'Both like shade'},
      {
        'id': 'both',
        'component': 'SideBySide',
        'plants': {'path': '/plants'},
      },
    ]);

    expect(
      tester.widget<SideBySide>(find.byType(SideBySide)).plants,
      same(browse.plants),
    );
    final note = tester.widget<KitNote>(find.byType(KitNote));
    expect(note.rule, isNull);
    expect(note.slant, FontStyle.italic);
    expect(find.text('Both like shade'), findsOneWidget);
    expect(find.text('Fern a | Fern b'), findsOneWidget);
  });

  testWidgets('an action whose argument has no value now is off, one id may '
      'show twice, and a required null is refused', (tester) async {
    final session = await draw(
      tester,
      [
        {
          'id': 'root',
          'component': 'KitStack',
          'children': ['title', 'title', 'open'],
        },
        {
          'id': 'title',
          'component': 'KitText',
          'value': 'Hi',
          'style': 'plain',
        },
        {
          'id': 'open',
          'component': 'KitButton',
          'label': 'Pick the fifth',
          'onPressed': _action('pick', {
            'plant': {'path': '/plants/4'},
          }),
        },
      ],
      after: [
        (_) => [
          _show([
            {
              'id': 'root',
              'component': 'KitText',
              'value': null,
              'style': 'plain',
            },
          ]),
        ],
        (_) => const [.say('Sorry.')],
      ],
    );

    expect(find.text('Hi'), findsNWidgets(2));
    expect(tester.widget<KitButton>(find.byType(KitButton)).onPressed, isNull);

    session.send('Show nothing');
    await tester.pumpAndSettle();
    expect(
      AgentRequest(bodies.last).latestToolResults.single.value,
      containsPair('reason', 'root: KitText needs "value".'),
    );
  });

  testWidgets('an action passes a null of the data by path', (tester) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitButton',
        'label': 'Keep the note',
        'onPressed': _action('set_note', {
          'note': {'path': '/note'},
        }),
      },
    ]);

    await tester.tap(find.text('Keep the note'));
    await tester.pumpAndSettle();
    expect(browse.notes, [null]);
  });

  testWidgets('an action is off while a path it reads is null for a '
      'parameter that takes no null', (tester) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitButton',
        'label': 'Keep the note',
        'onPressed': _action('keep_note', {
          'note': {'path': '/note'},
        }),
      },
    ]);

    expect(tester.widget<KitButton>(find.byType(KitButton)).onPressed, isNull);

    browse.notes.add('Call first');
    browse.changed();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep the note'));
    await tester.pumpAndSettle();
    expect(browse.kept, ['Call first']);
  });

  testWidgets('an object the agent writes for a method passes as it is, '
      'though it has a path', (tester) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitButton',
        'label': 'Attach',
        'onPressed': _action('attach', {
          'file': {'path': 'docs/a.txt', 'title': 'A'},
        }),
      },
    ]);

    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();
    expect(browse.attached, ['docs/a.txt']);
  });

  testWidgets('an action passes lists of lists of objects by path', (
    tester,
  ) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitButton',
        'label': 'Compare',
        'onPressed': _action('compare', {
          'pairs': {'path': '/pairs'},
        }),
      },
    ]);

    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    final [[first, second]] = browse.compared.single;
    expect(first, same(browse.plants[0]));
    expect(second, same(browse.plants[1]));
  });

  testWidgets('an action is off while the screen does not list what its '
      'argument reads, and a row that needs it leaves', (tester) async {
    final keepTheNote = _action('set_note', {
      'note': {'path': '/note'},
    });
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': ['keep', 'row'],
      },
      {
        'id': 'keep',
        'component': 'KitButton',
        'label': 'Keep the note',
        'onPressed': keepTheNote,
      },
      {
        'id': 'row',
        'component': 'PlantRow',
        'plant': {'path': '/plants/0'},
        'onPick': keepTheNote,
      },
    ]);
    VoidCallback? keep() =>
        tester.widget<KitButton>(find.byType(KitButton)).onPressed;

    browse
      ..showsNote = false
      ..changed();
    await tester.pumpAndSettle();
    expect(keep(), isNull);
    expect(find.byType(PlantRow), findsNothing);

    browse
      ..showsNote = true
      ..changed();
    await tester.pumpAndSettle();
    expect(keep(), isNotNull);
    expect(find.byType(PlantRow), findsOneWidget);
  });

  testWidgets('a view of components that share their children is refused for '
      'its size at once', (tester) async {
    final layers = [
      for (var layer = 0; layer < 40; layer++)
        {
          'id': layer == 0 ? 'root' : 'layer$layer',
          'component': 'KitStack',
          'children': ['layer${layer + 1}', 'layer${layer + 1}'],
        },
      {'id': 'layer40', 'component': 'KitText', 'value': 'x', 'style': 'plain'},
    ];
    await draw(
      tester,
      layers,
      after: [
        (_) => const [.say('Too big.')],
      ],
    );

    expect(
      AgentRequest(bodies.last).latestToolResults.single.value,
      containsPair('reason', contains('more than 500 components')),
    );
  });

  testWidgets('an action that needs approval is off on a screen without '
      'approvals', (tester) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitButton',
        'label': 'Compost',
        'onPressed': _action('compost', {
          'plant': {'path': '/plants/0'},
        }),
      },
    ], approvals: const .none());

    expect(tester.widget<KitButton>(find.byType(KitButton)).onPressed, isNull);
  });

  testWidgets('a wake from onEvent after an action gives the agent its note '
      'and the data now, once', (tester) async {
    await draw(
      tester,
      [
        {
          'id': 'root',
          'component': 'PotsField',
          'pots': {'path': '/wanted'},
          'onPots': _action('set_pots', {
            'pots': {'input': true},
          }),
        },
      ],
      onEvent: (event, session) {
        if (event case AgentCall(caller: .view)) session.wake();
      },
      after: [
        (_) => const [.say('Three pots, noted.')],
      ],
    );

    await tester.tap(find.text('2 pots'));
    await tester.pumpAndSettle();

    final woken = AgentRequest(bodies.last);
    expect(woken.newNotes, [
      {
        'pressed': 'set_pots',
        'arguments': {'pots': 3},
        'status': 'returned',
        'result': null,
      },
    ]);
    expect(woken.context('wanted'), 3);
    expect(bodies, hasLength(2));
  });

  testWidgets('a view taken off the screen calls nothing and leaves the '
      'tool, and a new one starts empty', (tester) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    late TandemSession session;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: TandemScope.connected(
          surface: (context) => browse,
          connection: ScriptedAgent([
            for (var turn = 0; turn < 3; turn++)
              (body) {
                bodies.add(body);
                return [
                  if (turn == 0) _show(const GreenhouseCatalog().example),
                  const .say('Done.'),
                ];
              },
          ]),
          approvals: const .fromState(),
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return ValueListenableBuilder(
                valueListenable: shown,
                builder: (context, show, _) => SingleChildScrollView(
                  child: show
                      ? const TandemView(catalog: GreenhouseCatalog())
                      : const SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );
    session.send('Show them');
    await tester.pumpAndSettle();
    final staleTap = tester
        .widget<PlantRow>(find.byType(PlantRow).first)
        .onPick;

    shown.value = false;
    await tester.pumpAndSettle();
    staleTap();
    session.send('Anything new?');
    await tester.pumpAndSettle();
    shown.value = true;
    await tester.pumpAndSettle();

    expect(browse.picked, isNull);
    expect(_toolNames(bodies[1]), isNot(contains('tandem_show_view')));
    expect(find.byType(PlantRow), findsNothing);
    session.send('Show them again');
    await tester.pumpAndSettle();
    expect(_toolNames(bodies[2]), contains('tandem_show_view'));
  });

  testWidgets('the example draws on an empty list', (tester) async {
    browse.setPlants(const []);
    await draw(tester, const GreenhouseCatalog().example);

    expect(tester.takeException(), isNull);
    expect(find.text('Greenhouse'), findsOneWidget);
    expect(find.byType(PlantRow), findsNothing);
  });

  testWidgets('a list below a null draws no items until the data has it', (
    tester,
  ) async {
    await draw(tester, [
      {
        'id': 'root',
        'component': 'KitStack',
        'children': {'componentId': 'item', 'path': '/featured/items'},
      },
      {
        'id': 'item',
        'component': 'KitText',
        'value': {'path': ''},
        'style': 'plain',
      },
    ]);
    expect(tester.takeException(), isNull);
    expect(find.byType(KitText), findsNothing);

    browse.setFeatured(_shelf(0, items: 2));
    await tester.pumpAndSettle();
    expect(find.text('item 0.1'), findsOneWidget);

    browse.setFeatured(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(KitText), findsNothing);
    expect(find.text('Too large'), findsNothing);
  });

  testWidgets('an example that does not fit the screen fails in debug', (
    tester,
  ) async {
    await draw(
      tester,
      const GreenhouseCatalog().example,
      surface: LookCubit(),
      after: [
        (_) => const [.say('I cannot draw that here.')],
      ],
    );

    expect(
      tester.takeException(),
      isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('/plants is not in the data'),
      ),
    );
  });
}

List<Object?> _toolNames(Map<String, Object?> body) => switch (body['tools']) {
  final List<Object?> tools => [
    for (final tool in tools)
      if (tool case {'name': final String name}) name,
  ],
  _ => const [],
};

// As a model writes it: the components as a JSON string.
AgentStep _show(List<Map<String, Object?>> components) =>
    .callTool('tandem_show_view', {'components': jsonEncode(components)});

Map<String, Object?> _action(String method, Map<String, Object?> context) => {
  'action': {
    'event': {'name': method, 'context': context},
  },
};

/// The greenhouse catalog, counting how often its components are built.
final class _CountingCatalog() implements AgentCatalog {
  int reads = 0;

  @override
  List<AgentComponent> get components {
    reads++;
    return const GreenhouseCatalog().components;
  }

  @override
  String get guidelines => const GreenhouseCatalog().guidelines;

  @override
  List<Map<String, Object?>> get example => const GreenhouseCatalog().example;
}

List<Map<String, Object?>> _shade(String name) => [
  {'id': 'root', 'component': 'Shade', 'name': name},
];

/// One text, in a shade that a converter of the app reads.
final class const _ShadeCatalog() implements AgentCatalog {
  @override
  List<AgentComponent> get components => [
    AgentComponent<Text>.of(
      name: 'Shade',
      description: 'A shade by its name.',
      properties: (property) => [
        property<String>('name').value(
          .converted(
            const _ShadeConverter(),
            AgentType.string,
            id: 'test#Shade',
            converterId: 'test#ShadeConverter()',
          ),
        ),
      ],
      build: (args) => Text(args.value('name')),
    ),
  ];

  @override
  String get guidelines => 'Draw one shade.';

  @override
  List<Map<String, Object?>> get example => _shade('grey');
}

final class const _ShadeConverter() implements JsonConverter<String, String> {
  /// The names it fails on, as a bug would.
  static final bugs = <String>{};

  @override
  String fromJson(String json) =>
      bugs.contains(json) ? throw StateError('A bug of the app.') : json;

  @override
  String toJson(String object) => object;
}

Shelf _shelf(int index, {required int items}) => .new(
  name: 'shelf $index',
  items: [for (var item = 0; item < items; item++) 'item $index.$item'],
);

PlantDTO _plant(String sku) => .new(
  sku: sku,
  label: 'Fern $sku',
  light: .partShade,
  sizes: [.new(diameterCm: 12, liters: 0.75, glazed: true)],
  pottedOn: .utc(2026, 3, 14),
  careSheet: .parse('https://care.example.com/$sku.pdf'),
);
