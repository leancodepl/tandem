import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/genui/view_widgets.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

import '../support/run_bodies.dart';
import '../support/shop.dart';
import '../support/views.dart';

void main() {
  late Shop shop;

  Widget screen(
    AgentConnection agent, {
    Widget view = const TandemView(),
    TandemApprovals approvals = const .fromState(),
    void Function(TandemEvent event)? onEvent,
    AgentSurface? surface,
  }) => MaterialApp(
    home: Scaffold(
      body: TandemScope.connected(
        surface: (context) => surface ?? shop,
        connection: agent,
        approvals: approvals,
        onEvent: (context, event, session) => onEvent?.call(event),
        child: Column(children: [view, const _Chat()]),
      ),
    ),
  );

  TandemSession sessionOf(WidgetTester tester) =>
      TandemSessionScope.of(tester.element(find.byType(_Chat)));

  AgentStep show(List<Map<String, Object?>> messages) =>
      AgentStep.callTool('tandem_show_view', {'messages': messages});

  /// A script that draws [view] on the first message, then plays [turns].
  ScriptedAgent drawingAgent(
    List<Map<String, Object?>> view, [
    List<AgentTurn> turns = const [],
  ]) => ScriptedAgent([
    (_) => [show(view)],
    (_) => const [AgentStep.say('There it is.')],
    ...turns,
  ]);

  Future<void> draw(WidgetTester tester) async {
    sessionOf(tester).send('show it');
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label, {int at = 0}) => tester
      .widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.bySubtype<ButtonStyleButton>(),
            )
            .at(at),
      )
      .enabled;

  ApprovalRequest lastRequest(WidgetTester tester) =>
      sessionOf(tester).items.whereType<ApprovalRequest>().last;

  testWidgets('a run offers tandem_show_view after the listed methods only '
      'while a TandemView is on the screen', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => const [AgentStep.say('Hi.')],
      (_) => const [AgentStep.say('Hi again.')],
    ]);
    await tester.pumpWidget(screen(agent, view: const SizedBox()));
    sessionOf(tester).send('hi');
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('hi again');
    await tester.pumpAndSettle();

    expect(
      [for (final request in agent.requests) _toolNames(request)],
      [
        ['add', 'remove_at', 'refresh', 'clear', 'share'],
        ['add', 'remove_at', 'refresh', 'clear', 'share', 'tandem_show_view'],
      ],
    );
  });

  testWidgets('a view the agent sends shows what .sees lists, follows it, and '
      'the next run hears that it shows', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();

    expect(find.text('First: milk'), findsOneWidget);
    expect(find.text('bread'), findsOneWidget);
    expect(_lastAnswer(agent.requests[1]), {'status': 'shown'});

    shop.add('eggs');
    await tester.pumpAndSettle();
    expect(find.text('eggs'), findsOneWidget);
  });

  testWidgets('list growth hides an over-budget view and its old actions, '
      'then recovery waits until the drawing fits the screen again', (
    tester,
  ) async {
    shop = _newShop();
    final agent = drawingAgent(shoppingListView);
    await tester.pumpWidget(screen(agent));
    await draw(tester);
    final oldPress = tester
        .widget<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>().first)
        .onPressed;

    shop.items.addAll(List.filled(200, 'extra'));
    shop.showTab(1);
    await tester.pumpAndSettle();

    expect(shop.items, hasLength(202));
    expect(find.text('bread'), findsNothing);
    expect(find.bySubtype<ButtonStyleButton>(), findsNothing);
    expect(
      find.text('This view is unavailable for the current screen data.'),
      findsOneWidget,
    );
    oldPress?.call();
    await tester.pumpAndSettle();
    expect(shop.items, hasLength(202));

    shop.items.clear();
    shop.showTab(2);
    await tester.pumpAndSettle();
    expect(find.bySubtype<ButtonStyleButton>(), findsNothing);
    expect(
      find.text('This view is unavailable for the current screen data.'),
      findsOneWidget,
    );

    shop.items.addAll(['milk', 'bread']);
    shop.showTab(3);
    await tester.pumpAndSettle();
    expect(find.text('bread'), findsOneWidget);
    expect(enabled(tester, 'again'), isTrue);
    await tester.tap(find.text('again').first);
    await tester.pumpAndSettle();
    expect(shop.items, ['milk', 'bread', 'milk']);
  });

  testWidgets('complete snapshots retire the old resolver before updating '
      'any data and stay bounded as multiple .sees change together', (
    tester,
  ) async {
    final data = ViewData({
      'outer': [0],
      'inner': List.filled(200, 0),
      'nullable': null,
    });
    addTearDown(data.close);
    final messages = drawing([
      {
        'id': 'root',
        'component': 'List',
        'children': {'componentId': 'row', 'path': '/outer'},
      },
      {
        'id': 'row',
        'component': 'List',
        'children': {'componentId': 'cell', 'path': '/inner'},
      },
      {'id': 'cell', 'component': 'Text', 'text': 'Cell'},
    ]);
    final agent = drawingAgent(messages);
    await tester.pumpWidget(
      screen(
        agent,
        surface: data,
        view: const Expanded(child: SingleChildScrollView(child: TandemView())),
      ),
    );
    await draw(tester);
    final oldRoot = tester.widget<DrawnSurface>(find.byType(DrawnSurface)).root;
    final oldData = oldRoot.context?.surface.dataModel;
    var snapshots = 0;
    final subscription = oldData?.subscribe<Object?>('/', (_) {
      expect(oldRoot.disposed, isTrue);
      snapshots++;
    });

    data.replace({
      'outer': List.filled(200, 0),
      'inner': [0],
      'nullable': null,
    });
    await tester.pumpAndSettle();
    expect(snapshots, 1);
    expect(oldRoot.disposed, isTrue);
    expect(find.text('Cell'), findsNWidgets(200));
    final root = tester.widget<DrawnSurface>(find.byType(DrawnSurface)).root;
    final current = root.context?.surface.dataModel.get('/');
    expect(current, {
      'outer': List.filled(200, 0),
      'inner': [0],
      'nullable': null,
    });
    subscription?.unsubscribe();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a view that does not fit is refused with what to fix, and the '
      'last view stays', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
      (_) => [
        show(
          drawing([
            {
              'id': 'root',
              'component': 'Column',
              'children': ['empty'],
            },
            ...button('empty', {'name': 'empty_the_list'}),
          ]),
        ),
      ],
      (_) => const [AgentStep.say('I cannot.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();
    sessionOf(tester).send('add a button to empty it');
    await tester.pumpAndSettle();

    expect(_lastAnswer(agent.requests[3]), {
      'status': 'refused',
      'reason': startsWith('empty must call a method of the screen'),
    });
    expect(find.text('First: milk'), findsOneWidget);
  });

  testWidgets('after three refused views in a row, the agent answers in text '
      'and gets no tandem_show_view until the next message', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(const [])],
      (_) => [show(const [])],
      (_) => [show(const [])],
      (_) => const [AgentStep.say('I could not draw it.')],
      (_) => const [AgentStep.say('Let me try again.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();

    expect(_lastAnswer(agent.requests[2]), containsPair('status', 'refused'));
    expect(
      _lastAnswer(agent.requests[3]),
      containsPair('reason', contains('Answer the user in text')),
    );
    expect(_toolNames(agent.requests[3]), isNot(contains('tandem_show_view')));

    sessionOf(tester).send('try again');
    await tester.pumpAndSettle();
    expect(_toolNames(agent.requests[4]), contains('tandem_show_view'));
  });

  testWidgets('a new view replaces the whole last one', (tester) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
      (_) => [
        show(
          drawing([
            {'id': 'root', 'component': 'Text', 'text': 'Just a text'},
          ]),
        ),
      ],
      (_) => const [AgentStep.say('Simpler now.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();
    sessionOf(tester).send('make it simpler');
    await tester.pumpAndSettle();

    expect(find.text('Just a text'), findsOneWidget);
    expect(find.text('bread'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refused accessibility metadata keeps the last view and its '
      'default Flutter semantics', (tester) async {
    shop = _newShop();
    final semantics = tester.ensureSemantics();
    final agent = drawingAgent(shoppingListView, [
      (_) => [
        show(
          drawing([
            {
              'id': 'root',
              'component': 'Text',
              'text': 'Replacement',
              'accessibility': <String, Object?>{},
            },
          ]),
        ),
      ],
      (_) => const [AgentStep.say('I cannot.')],
    ]);
    await tester.pumpWidget(screen(agent));
    await draw(tester);
    expect(find.bySemanticsLabel(RegExp('bread')), findsWidgets);
    expect(find.bySemanticsLabel('share'), findsOneWidget);

    sessionOf(tester).send('replace it');
    await tester.pumpAndSettle();

    expect(_lastAnswer(agent.requests[3]), {
      'status': 'refused',
      'reason': contains('component accessibility metadata is not supported'),
    });
    expect(find.text('Replacement'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('bread')), findsWidgets);
    expect(find.bySemanticsLabel('share'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the status says the agent draws from the start of '
      'tandem_show_view until its next text', (tester) async {
    shop = _newShop();
    final stream = StreamController<Map<String, Object?>>();
    addTearDown(stream.close);
    await tester.pumpWidget(screen(_FirstRun(stream.stream)));
    sessionOf(tester).send('show my list');

    stream.add({
      'type': 'TOOL_CALL_START',
      'toolCallId': 'c1',
      'toolCallName': 'tandem_show_view',
    });
    await tester.pump();
    expect(sessionOf(tester).status, const Thinking(drawing: true));
    stream.add({
      'type': 'TEXT_MESSAGE_CONTENT',
      'messageId': 'm1',
      'delta': 'Here.',
    });
    await tester.pump();
    expect(sessionOf(tester).status, const Thinking());
  });

  testWidgets('once the TandemView is gone, a call of the open run is refused '
      'and the next run no longer offers tandem_show_view', (tester) async {
    shop = _newShop();
    final gate = Completer<void>();
    final agent = ScriptedAgent([
      (_) => [AgentStep.waitFor(gate.future), show(shoppingListView)],
      (_) => const [AgentStep.say('It is gone.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pump();
    await tester.pumpWidget(screen(agent, view: const SizedBox()));
    gate.complete();
    await tester.pumpAndSettle();

    expect(_lastAnswer(agent.requests[1]), {
      'status': 'refused',
      'reason': 'No view is on the screen now.',
    });
    expect(_toolNames(agent.requests[1]), isNot(contains('tandem_show_view')));
  });

  testWidgets('a press calls the method for the view, onEvent hears it, and '
      'the next run reads in app_notes what it answered', (tester) async {
    shop = _newShop();
    final events = <TandemEvent>[];
    final agent = drawingAgent(shoppingListView, [
      (_) => const [AgentStep.say('You added milk.')],
    ]);
    await tester.pumpWidget(screen(agent, onEvent: events.add));
    await draw(tester);

    await tester.tap(find.text('again').first);
    await tester.pumpAndSettle();
    expect(shop.items, ['milk', 'bread', 'milk']);
    expect(events, [
      isA<AgentCall>()
          .having((call) => call.tool, 'tool', 'add')
          .having((call) => call.caller, 'caller', Caller.view),
    ]);

    sessionOf(tester).send('what did I do?');
    await tester.pumpAndSettle();
    expect(appNotesOf(agent.requests[2]), {
      'new': [
        {
          'pressed': 'add',
          'arguments': {'item': 'milk'},
          'status': 'returned',
          'result': null,
        },
      ],
    });
    expect(
      jsonEncode(agent.requests[2]['messages']),
      isNot(contains('pressed')),
    );
  });

  testWidgets('a press on a method that needs approval asks the user for the '
      'view; rejected, it runs nothing and tells the agent nothing', (
    tester,
  ) async {
    shop = _newShop();
    final events = <TandemEvent>[];
    final agent = drawingAgent(shoppingListView, [
      (_) => const [AgentStep.say('You shared it.')],
    ]);
    await tester.pumpWidget(screen(agent, onEvent: events.add));
    await draw(tester);

    await tester.tap(find.text('share'));
    await tester.pump();
    final request = lastRequest(tester);
    expect(request.caller, Caller.view);
    expect(sessionOf(tester).status, AwaitingApproval(request));
    sessionOf(tester).reject(request);
    await tester.pumpAndSettle();
    await tester.tap(find.text('share'));
    await tester.pump();
    sessionOf(tester).approve(lastRequest(tester));
    await tester.pumpAndSettle();
    sessionOf(tester).send('did it go?');
    await tester.pumpAndSettle();

    expect(events, [
      isA<AgentCall>()
          .having((call) => call.tool, 'tool', 'share')
          .having((call) => call.caller, 'caller', Caller.view),
    ]);
    expect(appNotesOf(agent.requests[2]), {
      'new': [
        {
          'pressed': 'share',
          'arguments': <String, Object?>{},
          'status': 'returned',
          'result': null,
        },
      ],
    });
  });

  testWidgets('a button that needs approval is disabled while the session is '
      'not idle', (tester) async {
    shop = _newShop();
    final gate = Completer<void>();
    final agent = drawingAgent(shoppingListView, [
      (_) => [AgentStep.waitFor(gate.future), const AgentStep.say('Hi.')],
      (_) => const [AgentStep.callTool('share')],
      (_) => const [AgentStep.say('Not shared.')],
    ]);
    await tester.pumpWidget(screen(agent));
    await draw(tester);
    expect(enabled(tester, 'share'), isTrue);

    sessionOf(tester).send('hi');
    await tester.pump();
    expect(enabled(tester, 'share'), isFalse);
    expect(enabled(tester, 'again'), isTrue);
    gate.complete();
    await tester.pumpAndSettle();
    expect(enabled(tester, 'share'), isTrue);

    sessionOf(tester).send('share it');
    await tester.pumpAndSettle();
    expect(enabled(tester, 'share'), isFalse);
    sessionOf(tester).reject(lastRequest(tester));
    await tester.pumpAndSettle();
    expect(enabled(tester, 'share'), isTrue);
  });

  testWidgets('a button of a method the screen does not list now is disabled, '
      'and so is one that needs approval on a screen that takes none', (
    tester,
  ) async {
    shop = _newShop();
    final view = drawing([
      {
        'id': 'root',
        'component': 'Row',
        'children': ['clear', 'share'],
      },
      ...button('clear', {'name': 'clear'}),
      ...button('share', {'name': 'share'}),
    ]);
    await tester.pumpWidget(screen(drawingAgent(view)));
    await draw(tester);
    expect(enabled(tester, 'clear'), isTrue);

    shop
      ..removeAt(0)
      ..removeAt(0);
    await tester.pumpAndSettle();
    expect(enabled(tester, 'clear'), isFalse);

    shop.add('milk');
    await tester.pumpWidget(
      screen(drawingAgent(view), approvals: const .none()),
    );
    await draw(tester);
    expect(enabled(tester, 'share'), isFalse);
  });

  testWidgets('a press keeps its own button pressed until its call answers, '
      'not the other buttons of its list template', (tester) async {
    shop = _newShop();
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final view = drawing([
      {
        'id': 'root',
        'component': 'List',
        'children': {'componentId': 'line', 'path': '/items'},
      },
      {
        'id': 'line',
        'component': 'Row',
        'children': ['name', 'refresh'],
      },
      {
        'id': 'name',
        'component': 'Text',
        'text': {'path': '.'},
      },
      ...button('refresh', {'name': 'refresh'}),
    ]);
    await tester.pumpWidget(screen(drawingAgent(view)));
    await draw(tester);

    await tester.tap(find.text('refresh').first);
    await tester.tap(find.text('refresh').first);
    expect(shop.refreshes, 1);
    await tester.tap(find.text('refresh').last);
    expect(shop.refreshes, 2);
    await tester.pump();
    expect(
      [enabled(tester, 'refresh'), enabled(tester, 'refresh', at: 1)],
      [isFalse, isFalse],
    );
    serverReply.complete();
    await tester.pumpAndSettle();
    expect(enabled(tester, 'refresh'), isTrue);
    await tester.tap(find.text('refresh').first);
    await tester.pumpAndSettle();
    expect(shop.refreshes, 3);
  });

  testWidgets('a message sent while the approved method of a press runs goes '
      'after it, and its run reads the press in app_notes', (tester) async {
    shop = _newShop();
    final serverReply = Completer<void>();
    shop.serverReply = serverReply.future;
    final agent = drawingAgent(shoppingListView, [
      (_) => const [AgentStep.say('Yes, you shared it.')],
    ]);
    await tester.pumpWidget(screen(agent));
    await draw(tester);

    await tester.tap(find.text('share'));
    await tester.pump();
    sessionOf(tester)
      ..approve(lastRequest(tester))
      ..send('did it go?');
    await tester.pump();
    expect(agent.requests, hasLength(2));
    serverReply.complete();
    await tester.pumpAndSettle();

    expect(messagesOf(agent.requests[2]).last['content'], 'did it go?');
    expect(appNotesOf(agent.requests[2]), {
      'new': [containsPair('pressed', 'share')],
    });
  });

  testWidgets('a request of the coding agent waits while one of a press '
      'shows, and shows once it is decided', (tester) async {
    shop = _newShop();
    await tester.pumpWidget(screen(drawingAgent(shoppingListView)));
    await draw(tester);

    await tester.tap(find.text('share'));
    await tester.pump();
    final answer = TandemBridge.call('clear');
    await tester.pump();
    expect(lastRequest(tester).caller, Caller.view);
    sessionOf(tester).approve(lastRequest(tester));
    await tester.pumpAndSettle();
    expect(lastRequest(tester).caller, Caller.codingAgent);
    sessionOf(tester).approve(lastRequest(tester));

    expect(await answer, containsPair('status', 'returned'));
    expect(shop.items, isEmpty);
  });

  testWidgets('a new session of the scope starts with an empty view', (
    tester,
  ) async {
    shop = _newShop();
    final agent = ScriptedAgent([
      (_) => [show(shoppingListView)],
      (_) => const [AgentStep.say('There it is.')],
    ]);
    await tester.pumpWidget(screen(agent));
    sessionOf(tester).send('show my list');
    await tester.pumpAndSettle();
    expect(find.text('bread'), findsOneWidget);

    await tester.pumpWidget(screen(ScriptedAgent([])));

    expect(find.text('bread'), findsNothing);
  });

  testWidgets('a newly mounted owner retires mounted view buttons and their '
      'cached callbacks without a build notification error', (tester) async {
    shop = _newShop();
    final thread = TandemThread();
    final replacement = ValueNotifier(false);
    addTearDown(replacement.dispose);
    TandemSession? newSession;
    final agent = drawingAgent(shoppingListView);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TandemScope.connected(
                surface: (context) => shop,
                connection: agent,
                thread: thread,
                approvals: const .fromState(),
                child: const Column(children: [TandemView(), _Chat()]),
              ),
              ValueListenableBuilder(
                valueListenable: replacement,
                builder: (context, replace, _) => replace
                    ? TandemScope.connected(
                        surface: (context) => shop,
                        connection: ScriptedAgent([]),
                        thread: thread,
                        approvals: const .fromState(),
                        child: Builder(
                          builder: (context) {
                            newSession = TandemSessionScope.of(context);
                            return const SizedBox.shrink();
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await draw(tester);
    final oldPress = tester
        .widget<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>().first)
        .onPressed;
    final oldView = tester.widget<DrawnSurface>(find.byType(DrawnSurface)).view;
    replacement.value = true;
    await tester.pumpAndSettle();

    expect(enabled(tester, 'again'), isFalse);
    expect(enabled(tester, 'share'), isFalse);
    oldPress?.call();
    await tester.pumpAndSettle();
    expect(shop.items, ['milk', 'bread']);
    expect(
      oldView.show({'messages': shoppingListView}).json,
      containsPair('status', 'refused'),
    );
    if (newSession case final active?) {
      await active.callFor(.view, 'refresh', {});
    }
    expect(shop.refreshes, 1);
    expect(tester.takeException(), isNull);
  });
}

/// Stands for the app's chat, to find the session by.
final class const _Chat() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Streams [_first] as its only run.
final class _FirstRun(final Stream<Map<String, Object?>> _first)
    implements AgentConnection {
  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) => _first;
}

List<Object?> _toolNames(Map<String, Object?> request) => switch (request) {
  {'tools': final List<Object?> tools} => [
    for (final tool in tools)
      if (tool case {'name': final name}) name,
  ],
  _ => const [],
};

/// The decoded answer of the last tool message of [request].
Object? _lastAnswer(Map<String, Object?> request) {
  final {'messages': messages as List<Object?>} = request;
  final answers = [
    for (final message in messages)
      if (message case {'role': 'tool', 'content': final String content})
        content,
  ];
  return jsonDecode(answers.last);
}

/// Called in each test, so that the shop's futures and stream belong to the
/// fake zone.
Shop _newShop() {
  final shop = Shop()..items.addAll(['milk', 'bread']);
  addTearDown(shop.close);
  return shop;
}
