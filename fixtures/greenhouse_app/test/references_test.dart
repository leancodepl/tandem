import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/contracts.dart';
import 'package:greenhouse_app/nursery_cubit.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  late NurseryCubit nursery;

  setUp(
    () => nursery = NurseryCubit(
      [_plant('a'), _plant('b')],
      [.new(seedlings: 24)],
    ),
  );

  testWidgets('the method gets the very objects the paths point at', (
    tester,
  ) async {
    final session = await _connect(tester, nursery, [
      (_) => [
        const .callTool('open_plant', {
          'plant': {'path': '/plants/1'},
        }),
        const .callTool('compare_plants', {
          'plants': [
            {'path': '/plants/1'},
            {'path': '/plants/0'},
          ],
        }),
      ],
      (_) => [const .say('Done.')],
    ]);

    session.send('Open b');
    await tester.pumpAndSettle();

    expect(nursery.opened, same(nursery.plants[1]));
    expect(nursery.compared[0], same(nursery.plants[1]));
    expect(nursery.compared[1], same(nursery.plants[0]));
  });

  testWidgets('a path that an earlier call of the run moved is refused', (
    tester,
  ) async {
    final answers = <AgentToolResult>[];
    final session = await _connect(tester, nursery, [
      (_) => [
        const .callTool('reverse_plants'),
        const .callTool('open_plant', {
          'plant': {'path': '/plants/0'},
        }),
      ],
      (body) {
        answers.addAll(AgentRequest(body).latestToolResults);
        return [const .say('Done.')];
      },
    ]);

    session.send('Open the first');
    await tester.pumpAndSettle();

    expect(nursery.opened, isNull);
    expect(answers.last.value, {
      'status': 'refused',
      'reason':
          'plant: /plants/0 changed since the agent read it. Read '
          'plants again.',
    });
  });

  testWidgets('a path past the end of a list that an earlier call shortened '
      'is refused, not failed', (tester) async {
    final answers = <AgentToolResult>[];
    final session = await _connect(tester, nursery, [
      (_) => [
        const .callTool('keep_first'),
        const .callTool('open_plant', {
          'plant': {'path': '/plants/1'},
        }),
      ],
      (body) {
        answers.addAll(AgentRequest(body).latestToolResults);
        return [const .say('Done.')];
      },
    ]);

    session.send('Open the second');
    await tester.pumpAndSettle();

    expect(nursery.opened, isNull);
    expect(answers.last.value, {
      'status': 'refused',
      'reason':
          'plant: /plants/1 changed since the agent read it. Read '
          'plants again.',
    });
  });

  test('an object or a path of another type is refused', () async {
    final listing = AgentListing.of(nursery);
    Matcher refused(String message) => throwsA(
      isA<ToolCallRefused>().having(
        (error) => error.message,
        'message',
        message,
      ),
    );

    await expectLater(
      listing.call('open_plant', {
        'plant': {'sku': 'x', 'label': 'Made up'},
      }),
      refused(
        'plant: write a path to a PlantDTO in the data, '
        'as {"path": "/..."}, not an object',
      ),
    );
    await expectLater(
      listing.call('open_plant', {
        'plant': {'path': '/trays/0'},
      }),
      refused(
        'plant: /trays/0 is a Tray, not a PlantDTO. '
        'Paths of that type: /plants/<i>.',
      ),
    );
  });

  test("a class with a converter is passed by path, and in the converter's "
      'form only where the agent writes it', () async {
    final listing = AgentListing.of(nursery);

    await expectLater(
      listing.call('assign_grower', {'grower': 'eve'}, approved: true),
      throwsA(
        isA<ToolCallRefused>().having(
          (error) => error.message,
          'message',
          'grower: write a path to a Grower in the data, as {"path": '
              '"/..."}, not an object',
        ),
      ),
    );
    await listing.call('assign_grower', {
      'grower': {'path': '/growers/1'},
    }, approved: true);
    await listing.call('add_grower', {'grower': 'eve'});

    expect(nursery.assigned, same(nursery.growers[1]));
    expect(nursery.added?.code, 'eve');
  });

  testWidgets('the approved method gets the tray as the request showed it', (
    tester,
  ) async {
    final session = await _discardFirstTray(tester, nursery);
    final request = _pending(session);

    session.approve(request);
    await tester.pumpAndSettle();

    expect(request.arguments, {
      'tray': {'seedlings': 24},
    });
    expect(nursery.discarded?.seedlings, 24);
    expect(nursery.discarded, isNot(same(nursery.trays.first)));
  });

  testWidgets('the approved method gets a grower that the converter builds '
      'from the form the request showed', (tester) async {
    final session = await _connect(tester, nursery, [
      (_) => [
        const .callTool('assign_grower', {
          'grower': {'path': '/growers/0'},
        }),
      ],
      (_) => [const .say('Done.')],
    ]);
    session.send('Assign Ana');
    await tester.pumpAndSettle();
    final request = _pending(session);

    session.approve(request);
    await tester.pumpAndSettle();

    expect(request.arguments, {'grower': 'ana'});
    expect(nursery.assigned?.code, 'ana');
    expect(nursery.assigned, isNot(same(nursery.growers.first)));
  });

  testWidgets('a tray thinned in place and back invalidates the request', (
    tester,
  ) async {
    final session = await _discardFirstTray(tester, nursery);
    final request = _pending(session);

    nursery.thinFirstTray(20);
    await tester.pumpAndSettle();
    nursery.thinFirstTray(24);
    await tester.pumpAndSettle();

    expect(() => session.approve(request), throwsA(isA<ApprovalNotPending>()));
    expect(nursery.discarded, isNull);
  });
}

Future<TandemSession> _discardFirstTray(
  WidgetTester tester,
  NurseryCubit nursery,
) async {
  final session = await _connect(tester, nursery, [
    (_) => [
      const .callTool('discard_tray', {
        'tray': {'path': '/trays/0'},
      }),
    ],
    (_) => [const .say('Done.')],
  ]);
  session.send('Discard the first tray');
  await tester.pumpAndSettle();
  return session;
}

Future<TandemSession> _connect(
  WidgetTester tester,
  AgentSurface surface,
  List<AgentTurn> turns,
) async {
  late TandemSession session;
  await tester.pumpWidget(
    TandemScope.connected(
      surface: (context) => surface,
      connection: ScriptedAgent(turns),
      approvals: const .fromState(),
      child: Builder(
        builder: (context) {
          session = TandemSessionScope.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return session;
}

ApprovalRequest _pending(TandemSession session) => switch (session.status) {
  AwaitingApproval(:final request) => request,
  final status => throw StateError('Expected an approval, got $status.'),
};

PlantDTO _plant(String sku) => .new(
  sku: sku,
  label: 'Fern $sku',
  light: .partShade,
  sizes: [.new(diameterCm: 12, liters: 0.75, glazed: true)],
  pottedOn: .utc(2026, 3, 14),
  careSheet: .parse('https://care.example.com/$sku.pdf'),
);
