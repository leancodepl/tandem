import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

import 'support.dart';

const _filled = OrderDraft(customer: 'Acme', quantity: 40);

/// The agent fills the whole draft and proposes to place the order.
List<AgentStep> _fillAndPropose(RunRequest request) => [
  AgentStep.patchState([
    {'op': 'replace', 'path': '/order', 'value': _filled.toJson()},
  ]),
  const AgentStep.say('I filled in the order. Shall I place it?'),
  const AgentStep.callTool('place_order'),
];

void main() {
  group('TandemScope', () {
    testWidgets('the agent fills the draft, the fields show it, and the '
        'order is placed once the user approves', (tester) async {
      final orders = Orders();
      final diagnostics = <TandemDiagnostic>[];
      final agent = ScriptedAgent([
        (request) {
          expect(request.userText, '40 HDMI cables for Acme');
          expect(request.state, {
            'order': {'customer': '', 'quantity': 0},
          });
          expect(request.input.tools.map((tool) => tool.name), ['place_order']);
          return _fillAndPropose(request);
        },
        (request) {
          expect(request.resultOf('place_order'), {
            'status': 'executed',
            'approved': true,
            'result': {'number': 'ZAM/2026/0042'},
          });
          return const [AgentStep.say('Placed as ZAM/2026/0042.')];
        },
      ]);
      await tester.pumpWidget(
        orderApp(
          connection: agent,
          orders: orders,
          route: orderRoute(
            cubit: OrderCubit(),
            options: TandemOptions(onDiagnostic: diagnostics.add),
          ),
        ),
      );

      await sendMessage(tester, '40 HDMI cables for Acme');

      expect(fieldText(tester, 'customer'), 'Acme');
      expect(fieldText(tester, 'quantity'), '40');
      expect(markOf('customer'), findsOneWidget);
      expect(markOf('quantity'), findsOneWidget);
      expect(
        find.text('I filled in the order. Shall I place it?'),
        findsOneWidget,
      );
      expect(find.text('Place the order'), findsOneWidget);
      expect(find.text('Working'), findsNothing);
      expect(orders.placed, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(orders.placed, [_filled]);
      expect(find.text('Placed'), findsOneWidget);
      expect(approveButton(tester).onPressed, isNull);
      expect(find.text('Placed as ZAM/2026/0042.'), findsOneWidget);
      expect(agent.isExhausted, isTrue);
      expect(diagnostics, isEmpty);
    });

    testWidgets('a user edit in a field makes the approval stale', (
      tester,
    ) async {
      final orders = Orders();
      await tester.pumpWidget(
        orderApp(
          connection: ScriptedAgent([_fillAndPropose]),
          orders: orders,
          route: orderRoute(cubit: OrderCubit()),
        ),
      );
      await sendMessage(tester, '40 HDMI cables for Acme');

      expect(approveButton(tester).onPressed, isNotNull);

      await tester.enterText(fieldOf('quantity'), '15');
      await tester.pumpAndSettle();

      expect(approveButton(tester).onPressed, isNull);
      expect(
        find.text('The details changed, ask the assistant again'),
        findsOneWidget,
      );
      expect(markOf('quantity'), findsNothing);
      expect(markOf('customer'), findsOneWidget);
      expect(orders.placed, isEmpty);
    });

    testWidgets('creates the session at once and reads codec, tools and '
        'options only then', (tester) async {
      var toolBuilds = 0;
      final agent = ScriptedAgent([
        (request) => const [AgentStep.say('Hello.')],
      ]);
      final cubit = OrderCubit();
      Widget scope({
        required StateCodec<OrderState> codec,
        required List<Tool<OrderState>> Function(BuildContext context) tools,
        required String threadId,
      }) => orderApp(
        connection: agent,
        route: BlocProvider(
          create: (context) => cubit,
          child: TandemScope<OrderCubit, OrderState>(
            codec: codec,
            tools: tools,
            options: TandemOptions(threadId: threadId),
            child: const SizedBox(key: Key('screen')),
          ),
        ),
      );
      TandemCubit tandemCubit() =>
          tester.element(find.byKey(const Key('screen'))).read<TandemCubit>();

      await tester.pumpWidget(
        scope(
          codec: orderCodec,
          tools: (context) {
            toolBuilds++;
            return orderTools(context);
          },
          threadId: 'first',
        ),
      );

      // Nothing below reads the TandemCubit, and the session exists anyway.
      expect(toolBuilds, 1);
      final session = tandemCubit().session;

      await tester.pumpWidget(
        scope(
          codec: StateCodec.json(
            'draft',
            (json) => const OrderState(),
            toJson: (state) => const {},
          ),
          tools: (context) {
            toolBuilds++;
            return const [];
          },
          threadId: 'second',
        ),
      );

      expect(toolBuilds, 1);
      expect(tandemCubit().session, same(session));
      expect(session.threadId, 'first');

      // Sent from the test body, outside the tester's calls, so the request
      // is checked after the run rather than inside the turn.
      unawaited(tandemCubit().send('Hi'));
      await tester.pumpAndSettle();

      final request = agent.requests.single;
      expect(request.input.threadId, 'first');
      expect(request.state.keys, ['order']);
      expect(request.input.tools.map((tool) => tool.name), ['place_order']);
      expect(session.view.error, isNull);
    });

    testWidgets('prefers its connection to the provided one', (tester) async {
      final provided = ScriptedAgent(const []);
      final own = ScriptedAgent([
        (request) => const [AgentStep.say('Hello.')],
      ]);
      await tester.pumpWidget(
        orderApp(
          connection: provided,
          route: orderRoute(cubit: OrderCubit(), connection: own),
        ),
      );

      await sendMessage(tester, 'Hi');

      expect(own.requests, hasLength(1));
      expect(provided.requests, isEmpty);
      expect(find.text('Hello.'), findsOneWidget);
    });

    testWidgets('explains how to provide a connection when there is none', (
      tester,
    ) async {
      final cubit = OrderCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(orderApp(route: orderRoute(cubit: cubit)));

      expect(
        tester.takeException(),
        isA<FlutterError>()
            .having(
              (error) => error.diagnostics.first.toString(),
              'summary',
              'TandemScope<OrderCubit, OrderState> found no AgentConnection. '
                  'Provide one above it with '
                  'RepositoryProvider<AgentConnection>, or pass '
                  'TandemScope.connection.',
            )
            .having(
              (error) => error.message,
              'message',
              contains('RepositoryProvider<AgentConnection>('),
            ),
      );
    });

    testWidgets('explains that a connection provided without its type is '
        'not found', (tester) async {
      final cubit = OrderCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider.value(
            value: ScriptedAgent(const []),
            child: orderRoute(cubit: cubit),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('found no AgentConnection'),
            contains('Without the type argument'),
          ),
        ),
      );
    });

    testWidgets('explains that it belongs under the BlocProvider of the '
        'host', (tester) async {
      await tester.pumpWidget(
        orderApp(
          connection: ScriptedAgent(const []),
          route: TandemScope<OrderCubit, OrderState>(
            codec: orderCodec,
            child: const SizedBox(),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.diagnostics.first.toString(),
          'summary',
          'TandemScope<OrderCubit, OrderState> found no OrderCubit above it. '
              'Put it under the BlocProvider<OrderCubit> that creates the '
              'cubit.',
        ),
      );
    });

    testWidgets('lets through what the provider of the connection is '
        'missing', (tester) async {
      final cubit = OrderCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<AgentConnection>(
            create: (context) => AgentConnection.http(context.read<Uri>()),
            child: orderRoute(cubit: cubit),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<ProviderNotFoundException>().having(
          (error) => error.valueType,
          'valueType',
          Uri,
        ),
      );

      // A RepositoryProvider whose create threw fails again when it is
      // disposed. That is provider's own behaviour, not the scope's.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isA<TypeError>());
    });

    testWidgets('closing the screen during a run never writes into the '
        'closed cubit', (tester) async {
      final resume = Completer<void>();
      final cubit = OrderCubit();
      final agent = ScriptedAgent([
        (request) => [
          const AgentStep.patchState([
            {'op': 'replace', 'path': '/order/customer', 'value': 'Acme'},
          ]),
          AgentStep.waitFor(resume.future),
          const AgentStep.patchState([
            {'op': 'replace', 'path': '/order/quantity', 'value': 40},
          ]),
          const AgentStep.say('Done.'),
        ],
      ]);
      await tester.pumpWidget(
        orderApp(
          connection: agent,
          route: orderRoute(cubit: cubit),
        ),
      );
      await sendMessage(tester, 'Acme, 40');
      final session = tester
          .element(find.byType(OrderScreen))
          .read<TandemCubit>()
          .session;

      expect(fieldText(tester, 'customer'), 'Acme');
      expect(session.view.isRunning, isTrue);

      await tester.pumpWidget(
        orderApp(connection: agent, route: const SizedBox()),
      );
      resume.complete();
      await tester.pumpAndSettle();

      expect(cubit.isClosed, isTrue);
      expect(cubit.state.draft, const OrderDraft(customer: 'Acme'));
      expect(() => session.send('Hi'), throwsStateError);
    });

    testWidgets('an agent event that arrives while the screen closes is '
        'dropped', (tester) async {
      final connection = LiveConnection();
      final cubit = OrderCubit();
      // Disposed after everything below it, so the event arrives after
      // both cubits were closed, before any of their futures completes.
      final route = _OnDispose(
        onDispose: () => connection.send(draftDelta(_filled)),
        child: orderRoute(cubit: cubit),
      );
      await tester.pumpWidget(orderApp(connection: connection, route: route));
      await sendMessage(tester, 'Acme, 40');
      connection.send(draftDelta(const OrderDraft(customer: 'Acme')));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'customer'), 'Acme');

      await tester.pumpWidget(
        orderApp(connection: connection, route: const SizedBox()),
      );
      await tester.pumpAndSettle();

      expect(cubit.isClosed, isTrue);
      expect(cubit.state.draft, const OrderDraft(customer: 'Acme'));
      expect(connection.isListening, isFalse);
    });
  });
}

/// Calls [onDispose] when it leaves the tree, after everything below it.
class _OnDispose extends StatefulWidget {
  const _OnDispose({required this.onDispose, required this.child});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_OnDispose> createState() => _OnDisposeState();
}

class _OnDisposeState extends State<_OnDispose> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
