import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_ai'),
          (_) async => <String, String>{},
        );
  });
  late FirebaseAI firebase;
  setUpAll(() async {
    final app = await Firebase.initializeApp();
    firebase = FirebaseAI.googleAI(app: app);
  });

  testWidgets(
    'a scope executes the proposed method and sends its real result to Firebase',
    (tester) async {
      final server = _Server([
        _reply([_addCall]),
        _reply([
          {'text': 'Added.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(
          FirebaseConnection(firebase: firebase, model: 'test-model'),
        );
        await screen.mount(tester);
        screen.session.send('add three');
        await screen.settle(tester);

        expect(
          screen.surface.value,
          3,
          reason:
              'status=${screen.session.status}, requests=${server.requests.length}, events=${screen.events}',
        );
        expect(screen.surface.executions, 1);
        expect(server.requests, hasLength(2));
        expect(screen.session.status, isA<Idle>());
        expect(
          screen.session.items.whereType<AgentMessage>().single.text,
          'Added.',
        );
        final contents = _contents(server.requests.last);
        expect(_parts(contents[1]), [
          {'thought': false, ..._addCall},
        ]);
        expect(_parts(contents[2]), [
          _functionResult('native-add', {'value': 3, 'execution': 1}),
          {'text': contains('"value":"3"')},
        ]);
        expect(screen.events.whereType<AgentCall>().single.result, {
          'value': 3,
          'execution': 1,
        });
      }, server.client);
    },
  );

  for (final decision in _Decision.values) {
    testWidgets(
      'Firebase receives the actual ${decision.name} approval outcome',
      (tester) async {
        final server = _Server([
          _reply([_addCall]),
          _reply([
            {'text': 'Understood.'},
          ]),
        ]);
        await http.runWithClient(() async {
          final screen = _Screen(
            FirebaseConnection(firebase: firebase, model: 'test-model'),
          );
          screen.surface.approval = true;
          await screen.mount(tester);
          screen.session.send('add three');
          await screen.settle(tester);
          final request = screen.session.items
              .whereType<ApprovalRequest>()
              .single;
          expect(request.status, ApprovalStatus.pending);
          expect(screen.surface.executions, 0);
          expect(server.requests, hasLength(1));

          switch (decision) {
            case .approve:
              screen.session.approve(request);
            case .reject:
              screen.session.reject(request);
            case .invalidate:
              screen.surface.edit(7);
              await tester.pumpAndSettle();
              expect(
                screen.session.items.whereType<ApprovalRequest>().single.status,
                ApprovalStatus.invalidated,
              );
              screen.session.send('keep seven');
          }
          await screen.settle(tester);

          expect(server.requests, hasLength(2));
          final result = _parts(_contents(server.requests.last)[2])
              .singleWhere((part) => part.containsKey('functionResponse'));
          switch (decision) {
            case .approve:
              expect(
                result,
                _functionResult('native-add', {'value': 3, 'execution': 1}),
              );
              expect(screen.surface.value, 3);
              expect(screen.surface.executions, 1);
            case .reject:
              expect(
                result,
                _functionResult('native-add', {'status': 'rejected_by_user'}),
              );
              expect(screen.surface.value, 0);
              expect(screen.surface.executions, 0);
            case .invalidate:
              expect(result, {
                'functionResponse': {
                  'id': 'native-add',
                  'name': 'add',
                  'response': {
                    'result': {
                      'status': 'invalidated',
                      'reason': isA<String>(),
                    },
                  },
                },
              });
              expect(screen.surface.value, 7);
              expect(screen.surface.executions, 0);
              expect(_parts(_contents(server.requests.last)[2]), [
                result,
                {'text': 'keep seven'},
                {'text': contains('"value":"7"')},
              ]);
          }
        }, server.client);
      },
    );
  }

  testWidgets(
    'Stop during generation keeps visible text and the next message works',
    (tester) async {
      final response = StreamController<List<int>>();
      final server = _Server([
        response.stream,
        _reply([
          {'text': 'Ready.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(
          FirebaseConnection(firebase: firebase, model: 'test-model'),
        );
        await screen.mount(tester);
        screen.session.send('think');
        await _pumpUntil(tester, () => server.requests.isNotEmpty);
        response.add(
          _chunk([
            {'text': 'Visible.'},
          ], finishReason: null),
        );
        await _pumpUntil(
          tester,
          () => screen.session.items.whereType<AgentMessage>().isNotEmpty,
        );
        expect(
          screen.session.items.whereType<AgentMessage>().single.text,
          'Visible.',
        );

        screen.session.stop();
        await screen.settle(tester);
        expect(screen.session.status, isA<Idle>());
        screen.session.send('continue');
        await screen.settle(tester);

        expect(server.requests, hasLength(2));
        expect(_contents(server.requests.last), [
          {
            'role': 'user',
            'parts': [
              {'text': 'think'},
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'text': 'Visible.'},
            ],
          },
          {
            'role': 'user',
            'parts': [
              {'text': 'continue'},
              {'text': contains('"value":"0"')},
            ],
          },
        ]);
        expect(screen.surface.executions, 0);
        expect(screen.events.whereType<RunStopped>(), hasLength(1));
        expect(screen.events.whereType<RunFailed>(), isEmpty);
        await response.close();
      }, server.client);
    },
  );

  testWidgets(
    'an app-ID reset sends retained signed calls and cancelled answers after scope handoff',
    (tester) async {
      final server = _Server([
        _reply([_addCall]),
        _reply([
          {'text': 'Kept.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(
          FirebaseConnection(firebase: firebase, model: 'test-model'),
          thread: TandemThread(id: ThreadId('order-42')),
        );
        screen.surface.approval = true;
        await screen.mount(tester);
        screen.session.send('add three');
        await screen.settle(tester);
        expect(screen.session.status, isA<AwaitingApproval>());
        screen.session.startOver();
        await tester.pumpWidget(const SizedBox());
        await screen.mount(tester);
        screen.session.send('keep it');
        await screen.settle(tester);

        expect(server.requests, hasLength(2));
        expect(_contents(server.requests.last), [
          {
            'role': 'user',
            'parts': [
              {'text': 'The conversation was reset.'},
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'thought': false, ..._addCall},
            ],
          },
          {
            'role': 'user',
            'parts': [
              _functionResult('native-add', {'status': 'cancelled'}),
              {'text': 'keep it'},
              {'text': contains('"value":"0"')},
            ],
          },
        ]);
        expect(screen.surface.executions, 0);
        expect(screen.session.thread.id, 'order-42');
        expect(screen.events.whereType<RunFailed>(), isEmpty);
      }, server.client);
    },
  );

  testWidgets(
    'Stop after generation completed reports incompatible retained calls instead of replaying them',
    (tester) async {
      final server = _Server([
        Stream.fromIterable([
          _chunk([
            {'text': 'Visible.'},
          ], finishReason: null),
          _chunk([
            {'text': 'Hidden.'},
            _addCall,
          ]),
        ]),
      ]);
      final reports = <FlutterErrorDetails>[];
      final reportError = FlutterError.onError;
      FlutterError.onError = reports.add;
      try {
        await http.runWithClient(() async {
          final screen = _Screen(
            _CompletedResponse(
              FirebaseConnection(firebase: firebase, model: 'test-model'),
            ),
          );
          await screen.mount(tester);
          var stopped = false;
          screen.session.addListener(() {
            if (stopped) return;
            if (screen.session.items.whereType<AgentMessage>().isNotEmpty) {
              stopped = true;
              screen.session.stop();
            }
          });
          screen.session.send('add three');
          await screen.settle(tester);
          expect(
            screen.session.items.whereType<AgentMessage>().single.text,
            'Visible.',
          );
          expect(screen.surface.executions, 0);
          screen.session.send('continue');
          await screen.settle(tester);

          expect(server.requests, hasLength(1));
          expect(
            screen.events.whereType<RunFailed>().single.code,
            FirebaseErrorCode.incompatibleHistory,
          );
          expect(screen.surface.executions, 0);
          expect(reports, hasLength(1));
        }, server.client);
      } finally {
        FlutterError.onError = reportError;
      }
    },
  );

  testWidgets(
    'Firebase can draw a catalog view and receives the shown result',
    (tester) async {
      final server = _Server([
        _reply([
          {
            'functionCall': {
              'id': 'native-view',
              'name': 'tandem_show_view',
              'args': {'components': jsonEncode(_view)},
            },
            'thoughtSignature': 'view-signature',
          },
        ]),
        _reply([
          {'text': 'Shown.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(
          FirebaseConnection(firebase: firebase, model: 'test-model'),
        );
        await screen.mount(tester, view: true);
        screen.session.send('show a summary');
        await screen.settle(tester);
        expect(find.text('Summary.'), findsOneWidget);
        expect(server.requests, hasLength(1));
        screen.session.send('continue');
        await screen.settle(tester);

        expect(server.requests, hasLength(2));
        expect(_parts(_contents(server.requests.last)[2]), [
          {
            'functionResponse': {
              'id': 'native-view',
              'name': 'tandem_show_view',
              'response': {
                'result': {'status': 'shown'},
              },
            },
          },
          {'text': 'continue'},
          {'text': contains('"value":"0"')},
        ]);
      }, server.client);
    },
  );
}

typedef _Json = Map<String, Object?>;

enum _Decision() {
  approve,
  reject,
  invalidate,
}

final class _Screen(final AgentConnection connection, {TandemThread? thread}) {
  this {
    addTearDown(surface.close);
  }

  final surface = _Counter();
  final events = <TandemEvent>[];
  final TandemThread thread = thread ?? TandemThread();
  late TandemSession session;

  Future<void> settle(WidgetTester tester) => _pumpUntil(
    tester,
    () => session.status is Idle || session.status is AwaitingApproval,
  );

  Future<void> mount(WidgetTester tester, {bool view = false}) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TandemScope.connected(
          surface: (context) => surface,
          connection: connection,
          thread: thread,
          approvals: const .fromState(),
          onEvent: (context, event, session) => events.add(event),
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return view ? TandemView(catalog: _Catalog()) : const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}

final class _Counter() implements AgentSurface {
  final _changes = StreamController<Object?>.broadcast();
  int value = 0;
  int executions = 0;
  bool approval = false;

  _Json add(int amount) {
    executions++;
    edit(value + amount);
    return {'value': value, 'execution': executions};
  }

  void edit(int next) {
    value = next;
    _changes.add(next);
  }

  Future<void> close() => _changes.close();

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(value),
    if (approval) .callsWithApproval(add) else .calls(add),
  ];

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [
      AgentView.of(() => value).as('value', 'The current total.', .integer),
    ],
    calls: [
      AgentTool(
        add,
        name: 'add',
        description: 'Adds an amount to the total.',
        parameters: const [AgentParameter<int>('amount', .integer)],
        invoke: (args) => add(args.read('amount')),
      ),
    ],
  );
}

final class _Server(final List<Stream<List<int>>> responses) {
  final requests = <_Json>[];

  http.Client client() => MockClient.streaming((request, body) async {
    final input = jsonDecode(utf8.decode(await body.toBytes())) as _Json;
    final index = requests.length;
    requests.add(input);
    return http.StreamedResponse(
      responses[index],
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
}

// A completed response can still wait in the subscription's event queue.
final class _CompletedResponse(final FirebaseConnection connection)
    implements StoppableAgentConnection {
  @override
  Stream<_Json> run(_Json input) async* {
    final events = await connection.run(input).toList();
    yield* Stream.fromIterable(events);
  }

  @override
  Future<void> stop(_Json input) => connection.stop(input);
}

final class _Catalog() implements AgentCatalog {
  @override
  String get guidelines => 'Draw one summary label.';

  @override
  List<_Json> get example => _view;

  @override
  List<AgentComponent> get components => [
    AgentComponent<Text>.of(
      name: 'Label',
      description: 'A text label.',
      properties: (property) => [property<String>('text').value(.string)],
      build: (args) => Text(args.value<String>('text')),
    ),
  ];
}

const _view = <_Json>[
  {'id': 'root', 'component': 'Label', 'text': 'Summary.'},
];

const _addCall = <String, Object?>{
  'functionCall': {
    'id': 'native-add',
    'name': 'add',
    'args': {'amount': 3},
  },
  'thoughtSignature': 'call-signature',
};

_Json _functionResult(String id, Object? result) => {
  'functionResponse': {
    'id': id,
    'name': 'add',
    'response': {'result': result},
  },
};

List<_Json> _contents(_Json request) {
  final {'contents': contents as List<Object?>} = request;
  return contents.cast<_Json>();
}

List<_Json> _parts(_Json content) {
  final {'parts': parts as List<Object?>} = content;
  return parts.cast<_Json>();
}

Stream<List<int>> _reply(List<_Json> parts) => Stream.value(_chunk(parts));

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100; frame++) {
    await tester.runAsync(() => pumpEventQueue(times: 2));
    await tester.pump(const Duration(milliseconds: 10));
    if (ready()) return;
  }
  fail('The Firebase session did not reach the expected state.');
}

List<int> _chunk(List<_Json> parts, {String? finishReason = 'STOP'}) =>
    utf8.encode(
      'data: ${jsonEncode({
        'candidates': [
          {
            'content': {'role': 'model', 'parts': parts},
            'finishReason': ?finishReason,
          },
        ],
      })}\n\n',
    );
