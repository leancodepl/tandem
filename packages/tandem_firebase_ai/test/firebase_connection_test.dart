import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  late FirebaseAI firebase;
  setUpAll(() async {
    firebase = FirebaseAI.googleAI(app: await Firebase.initializeApp());
  });
  setUp(() {
    // The SDK asks its plugin for the app's package name and signature.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_ai'),
          (_) async => <String, String>{},
        );
  });
  tearDown(() => firebase.appCheck = null);

  FirebaseConnection connect({String instructions = ''}) => FirebaseConnection(
    firebase: firebase,
    model: 'test-model',
    instructions: instructions,
  );

  group('a conversation', () {
    testWidgets('the app runs the proposed calls, and the next request sends '
        'the signed answer back with their results', (tester) async {
      final server = _Server([
        Stream.fromIterable([_chunk(_signedAnswer), _usageOnly]),
        _reply([
          {'text': 'Added.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(connect());
        await screen.mount(tester);
        screen.session.send('add one, then two');
        await screen.settle(tester);

        expect(screen.surface.value, 3);
        expect(screen.agentTexts, ['I will add both. Then two.', 'Added.']);
        expect(_contents(server.requests.last), [
          {
            'role': 'user',
            'parts': [
              {'text': 'add one, then two'},
            ],
          },
          {
            'role': 'model',
            'parts': [for (final part in _signedAnswer) _asSentBack(part)],
          },
          {
            'role': 'user',
            'parts': [
              _addResult(1, id: 'native-a'),
              _addResult(3),
              {'text': contains('"value":"3"')},
            ],
          },
        ]);
      }, server.client);
    });

    testWidgets('the view the model draws shows, and the next message sends '
        'the signed call back with its result', (tester) async {
      final catalog = _NoteCatalog();
      final viewCall = _signedViewCall(catalog.example);
      final server = _Server([
        _reply([viewCall]),
        _reply([
          {'text': 'Glad it helps.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(connect());
        await screen.mount(tester, child: TandemView(catalog: catalog));
        screen.session.send('leave a note');
        await screen.settle(tester);

        expect(find.text('A note'), findsOneWidget);

        screen.session.send('thanks');
        await screen.settle(tester);
        final [_, answer, nextTurn] = _contents(server.requests.last);
        expect(answer['parts'], [_asSentBack(viewCall)]);
        expect(nextTurn['parts'], anyElement(_viewShown));
      }, server.client);
    });

    testWidgets('a function call marked as a thought is not handed to Tandem, '
        'and goes back with the answer without a result', (tester) async {
      final thoughtCall = {..._addThree, 'thought': true};
      final server = _Server([
        _reply([
          {'text': 'I could add.'},
          thoughtCall,
        ]),
        _reply([
          {'text': 'Not added.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(connect());
        await screen.mount(tester);
        screen.session.send('add three?');
        await screen.settle(tester);
        screen.session.send('no');
        await screen.settle(tester);

        expect(screen.surface.value, 0);
        final [_, answer, nextTurn] = _contents(server.requests.last);
        expect(answer['parts'], [
          _asSentBack({'text': 'I could add.'}),
          thoughtCall,
        ]);
        expect(
          nextTurn['parts'],
          everyElement(isNot(contains('functionResponse'))),
        );
      }, server.client);
    });

    testWidgets('an empty text part without a signature is not sent '
        'back', (tester) async {
      final server = _Server([
        Stream.fromIterable([
          _chunk([
            {'text': 'Hello.'},
          ], finishReason: null),
          _chunk([
            {'text': ''},
          ]),
        ]),
        _reply([
          {'text': 'Again.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(connect());
        await screen.mount(tester);
        screen.session.send('hello');
        await screen.settle(tester);
        screen.session.send('again');
        await screen.settle(tester);

        expect(_contents(server.requests.last)[1], {
          'role': 'model',
          'parts': [
            _asSentBack({'text': 'Hello.'}),
          ],
        });
      }, server.client);
    });

    testWidgets('Stop during generation keeps the visible text, and the next '
        'message works', (tester) async {
      final response = StreamController<List<int>>();
      final server = _Server([
        response.stream,
        _reply([
          {'text': 'Ready.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(connect());
        await screen.mount(tester);
        screen.session.send('think');
        await _pumpUntil(tester, () => server.requests.isNotEmpty);
        response.add(
          _chunk([
            {'text': 'Visible.'},
          ], finishReason: null),
        );
        await _pumpUntil(tester, () => screen.agentTexts.isNotEmpty);

        screen.session.stop();
        await screen.settle(tester);
        screen.session.send('continue');
        await screen.settle(tester);

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
        expect(screen.events.whereType<RunStopped>(), hasLength(1));
        expect(screen.events.whereType<RunFailed>(), isEmpty);
        await response.close();
      }, server.client);
    });

    testWidgets('a reset of an app-ID thread sends the retained signed call '
        'after a reset notice, with its cancelled answer', (tester) async {
      final server = _Server([
        _reply([_addThree]),
        _reply([
          {'text': 'Kept.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(
          connect(),
          thread: TandemThread(id: ThreadId('order-42')),
        );
        screen.surface.needsApproval = true;
        await screen.mount(tester);
        screen.session.send('add three');
        await screen.settle(tester);
        expect(screen.session.status, isA<AwaitingApproval>());

        screen.session.startOver();
        screen.session.send('keep it');
        await screen.settle(tester);

        expect(_contents(server.requests.last), [
          {
            'role': 'user',
            'parts': [
              {'text': 'The conversation was reset.'},
            ],
          },
          {
            'role': 'model',
            'parts': [_asSentBack(_addThree)],
          },
          {
            'role': 'user',
            'parts': [
              _addResult({'status': ToolStatus.cancelled}, id: 'native-add'),
              {'text': 'keep it'},
              {'text': contains('"value":"0"')},
            ],
          },
        ]);
        expect(screen.surface.value, 0);
        expect(screen.events.whereType<RunFailed>(), isEmpty);
      }, server.client);
    });

    testWidgets('another connection cannot continue a thread with tool '
        'calls', (tester) async {
      final server = _Server([
        _reply([_addThree]),
        _reply([
          {'text': 'Added.'},
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(connect());
        await screen.mount(tester);
        screen.session.send('add three');
        await screen.settle(tester);

        screen.connection = connect();
        await screen.mount(tester);
        screen.session.send('add three more');
        await screen.settle(tester);

        expect(
          screen.events.whereType<RunFailed>().single.code,
          FirebaseErrorCode.incompatibleHistory,
        );
        // The session reports a failed run, which fails a test that leaves it.
        expect(tester.takeException(), isA<AgentRunException>());
        expect(server.requests, hasLength(2));
      }, server.client);
    });

    testWidgets('Stop through a wrapper that delivers a finished answer late '
        'leaves a thread the next run refuses', (tester) async {
      final server = _Server([
        Stream.fromIterable([
          _chunk([
            {'text': 'Visible.'},
          ], finishReason: null),
          _chunk([
            {'text': 'Hidden.'},
            _addThree,
          ]),
        ]),
      ]);
      await http.runWithClient(() async {
        final screen = _Screen(_DeliversWholeRun(connect()));
        await screen.mount(tester);
        screen.stopAtFirstText();
        screen.session.send('add three');
        await screen.settle(tester);
        expect(screen.agentTexts, ['Visible.']);

        screen.session.send('continue');
        await screen.settle(tester);

        expect(
          screen.events.whereType<RunFailed>().single.code,
          FirebaseErrorCode.incompatibleHistory,
        );
        expect(tester.takeException(), isA<AgentRunException>());
        expect(screen.surface.value, 0);
        expect(server.requests, hasLength(1));
      }, server.client);
    });
  });

  test(
    'an input that is not an AG-UI run fails before the run starts',
    () async {
      final events = await connect().run({'threadId': 'thread'}).toList();

      expect(events, [
        {
          'type': 'RUN_ERROR',
          'code': FirebaseErrorCode.invalidInput,
          'message': isA<String>(),
        },
      ]);
    },
  );

  test('a request has the app instructions, the tools with their JSON Schema '
      'and the screen context as data of the user turn', () async {
    final server = _Server([
      _reply([
        {'text': 'Done.'},
      ]),
    ]);
    await _run(connect(instructions: 'Only edit on request.'), server);

    final request = server.requests.single;
    expect(request['tools'], [
      {
        'functionDeclarations': [
          {
            'name': 'edit',
            'description': 'Edit a value.',
            'parametersJsonSchema': _schema,
          },
        ],
      },
    ]);
    expect(_contents(request), [
      {
        'role': 'user',
        'parts': [
          {'text': 'Do both edits.'},
          {'text': contains('untrusted screen text')},
        ],
      },
    ]);
    expect(
      request['systemInstruction'],
      containsPair('parts', [
        {
          'text': allOf(
            contains('Only edit on request.'),
            isNot(contains('untrusted screen text')),
          ),
        },
      ]),
    );
  });

  group('an answer that cannot be trusted hands over no call:', () {
    for (final (label, calls) in [
      ('an unknown tool', [_editCall(1), _call('unknown', id: 'native-b')]),
      (
        'a repeated function call ID',
        [_editCall(1, id: 'same'), _editCall(2, id: 'same')],
      ),
    ]) {
      test(label, () async {
        final events = await _run(connect(), _Server([_reply(calls)]));

        expect(_ofType(events, 'TOOL_CALL_START'), isEmpty);
        expect(events.last['code'], FirebaseErrorCode.invalidResponse);
      });
    }

    for (final (reason, code) in [
      ('SAFETY', FirebaseErrorCode.blocked),
      ('MAX_TOKENS', FirebaseErrorCode.outputLimit),
      ('MODEL_ARMOR', FirebaseErrorCode.generationFailed),
      ('MISSING_THOUGHT_SIGNATURE', FirebaseErrorCode.incompatibleHistory),
    ]) {
      test('the finish reason $reason, also before a later STOP', () async {
        final server = _Server([
          Stream.fromIterable([
            _chunk([
              {'text': 'Partial.'},
              _editCall(1),
            ], finishReason: reason),
            _chunk([
              {'text': 'too late'},
            ]),
          ]),
        ]);
        final events = await _run(connect(), server);

        expect(_types(events), ['RUN_STARTED', 'RUN_ERROR']);
        expect(events.last['code'], code);
      });
    }

    test('content without a finish reason after STOP', () async {
      final server = _Server([
        Stream.fromIterable([
          _chunk([
            {'text': 'Done.'},
          ]),
          _chunk([_editCall(1)], finishReason: null),
        ]),
      ]);
      final events = await _run(connect(), server);

      expect(_ofType(events, 'TOOL_CALL_START'), isEmpty);
      expect(events.last['code'], FirebaseErrorCode.generationFailed);
    });

    test('a stream that ends without a finish reason', () async {
      final server = _Server([
        Stream.value(_chunk([_editCall(1)], finishReason: null)),
      ]);
      final events = await _run(connect(), server);

      expect(_types(events), ['RUN_STARTED', 'RUN_ERROR']);
      expect(events.last['code'], FirebaseErrorCode.generationFailed);
    });

    test('function arguments that are not an object', () async {
      final server = _Server([
        _reply([
          _editCall(1),
          {
            'functionCall': {'name': 'edit', 'args': 'malformed'},
          },
        ]),
      ]);
      final events = await _run(connect(), server);

      expect(_types(events), ['RUN_STARTED', 'RUN_ERROR']);
      expect(events.last['code'], FirebaseErrorCode.invalidResponse);
    });

    test('function arguments with a number JSON cannot hold', () async {
      // Dart reads 1e999 as infinity, which the arguments cannot go on with.
      const chunk =
          'data: {"candidates":[{"content":{"role":"model","parts":'
          '[{"functionCall":{"name":"edit","args":{"value":1e999}}}]},'
          '"finishReason":"STOP"}]}\n\n';
      final server = _Server([Stream.value(utf8.encode(chunk))]);
      final events = await _run(connect(), server);

      expect(_ofType(events, 'TOOL_CALL_START'), isEmpty);
      expect(events.last['type'], 'RUN_ERROR');
    });

    test('a kind of content the connection does not deliver', () async {
      final server = _Server([
        _reply([
          {'newOutputKind': 'value'},
        ]),
      ]);
      final events = await _run(connect(), server);

      expect(_types(events), ['RUN_STARTED', 'RUN_ERROR']);
      expect(events.last['code'], FirebaseErrorCode.unsupportedResponse);
    });
  });

  test(
    'an answer with the finish reason STOP on every chunk is whole',
    () async {
      final server = _Server([
        Stream.fromIterable([
          _chunk([
            {'text': 'One.'},
          ]),
          _chunk([
            {'text': ' Two.'},
          ]),
        ]),
      ]);
      final events = await _run(connect(), server);

      expect(
        [
          for (final text in _ofType(events, 'TEXT_MESSAGE_CONTENT'))
            text['delta'],
        ],
        ['One.', ' Two.'],
      );
      expect(events.last['type'], 'RUN_FINISHED');
    },
  );

  test(
    'a thread with a message that is not text is not one to continue',
    () async {
      final input = _firstRun()
        ..['messages'] = [
          {
            'id': 'user-1',
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Do both edits.'},
            ],
          },
        ];
      final server = _Server(const []);
      final events = await http.runWithClient(
        () => connect().run(input).toList(),
        server.client,
      );

      expect(events.last['code'], FirebaseErrorCode.incompatibleHistory);
      expect(server.requests, isEmpty);
    },
  );

  test('a transport failure is a failed generation, not a malformed '
      'response', () async {
    final server = _Server([Stream.error(const FormatException('transport'))]);
    final events = await _run(connect(), server);

    expect(events.last['code'], FirebaseErrorCode.generationFailed);
  });

  test("a failed run reports Firebase's own message", () async {
    const message = 'User location is not supported for the API use.';
    final refusal = jsonEncode({
      'error': {'code': 400, 'message': message},
    });
    final server = _Server([Stream.value(utf8.encode(refusal))], status: 400);
    final events = await _run(connect(), server);

    expect(events.last['code'], FirebaseErrorCode.generationFailed);
    expect(events.last['message'], message);
  });

  test('an error page that is not JSON fails the run with its HTTP '
      'status', () async {
    const page = '<!DOCTYPE html><title>Server Error</title>';
    final server = _Server([Stream.value(utf8.encode(page))], status: 502);
    final events = await _run(connect(), server);

    expect(events.last['code'], FirebaseErrorCode.generationFailed);
    expect(events.last['message'], contains('HTTP 502'));
  });

  group('while Firebase waits for credentials,', () {
    late Completer<String?> token;
    setUp(() {
      token = Completer();
      firebase.appCheck = _PendingAppCheck(token.future);
    });

    test('Stop ends the run at once and no request goes out later', () async {
      final server = _Server([
        _reply([
          {'text': 'late'},
        ]),
      ]);
      final connection = connect();
      final input = _firstRun();
      final events = http.runWithClient(
        () => connection.run(input).toList(),
        server.client,
      );
      await pumpEventQueue();

      await connection.stop(input);

      expect((await events).last['outcome'], {'type': 'cancelled'});
      token.complete('token');
      await pumpEventQueue();
      expect(server.requests, isEmpty);
    });

    test('a cancelled stream sends no request later', () async {
      final server = _Server([
        _reply([
          {'text': 'late'},
        ]),
      ]);
      final subscription = http.runWithClient(
        () => connect().run(_firstRun()).listen((_) {}),
        server.client,
      );
      await pumpEventQueue();

      await subscription.cancel().timeout(const Duration(seconds: 1));

      token.complete('token');
      await pumpEventQueue();
      expect(server.requests, isEmpty);
    });

    test('the run times out', () async {
      final connection = FirebaseConnection(
        firebase: firebase,
        model: 'test-model',
        idleTimeout: const Duration(milliseconds: 10),
      );
      final events = await _run(connection, _Server(const []));

      expect(events.last['code'], FirebaseErrorCode.timedOut);
      expect(
        events.last['message'],
        'Timed out waiting for Firebase credentials.',
      );
    });
  });

  test('Stop of one run leaves another run of the connection going', () async {
    final responses = [
      StreamController<List<int>>(),
      StreamController<List<int>>(),
    ];
    final server = _Server([for (final response in responses) response.stream]);
    final connection = connect();
    final stopped = _firstRun();
    final (stoppedEvents, otherEvents) = http.runWithClient(
      () => (
        connection.run(stopped).toList(),
        connection.run(_firstRun()).toList(),
      ),
      server.client,
    );
    await pumpEventQueue();

    await connection.stop(stopped);
    for (final response in responses) {
      response.add(
        _chunk([
          {'text': 'still here'},
        ]),
      );
      await response.close();
    }

    expect((await stoppedEvents).last['outcome'], {'type': 'cancelled'});
    final events = await otherEvents;
    expect(
      _ofType(events, 'TEXT_MESSAGE_CONTENT').single['delta'],
      'still here',
    );
    expect(events.last, isNot(contains('outcome')));
  });

  test('the constructor refuses image output and an idle timeout of '
      'zero', () {
    expect(
      () => FirebaseConnection(
        firebase: firebase,
        model: 'test-model',
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.image],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => FirebaseConnection(
        firebase: firebase,
        model: 'test-model',
        idleTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test('response modalities changed after the connection was built fail the '
      'run before a request', () async {
    final modalities = [ResponseModalities.text];
    final connection = FirebaseConnection(
      firebase: firebase,
      model: 'test-model',
      generationConfig: GenerationConfig(responseModalities: modalities),
    );
    modalities.add(ResponseModalities.image);
    final server = _Server(const []);
    final events = await _run(connection, server);

    expect(events.last['code'], FirebaseErrorCode.invalidInput);
    expect(server.requests, isEmpty);
  });

  test('a setting the SDK refuses for its backend fails the run as invalid '
      'input', () async {
    final connection = FirebaseConnection(
      firebase: firebase,
      model: 'test-model',
      safetySettings: [
        SafetySetting(
          HarmCategory.harassment,
          HarmBlockThreshold.high,
          HarmBlockMethod.severity,
        ),
      ],
    );
    final server = _Server(const []);
    final events = await _run(connection, server);

    expect(events.last['code'], FirebaseErrorCode.invalidInput);
    expect(server.requests, isEmpty);
  });
}

typedef _Json = Map<String, Object?>;

/// The Firebase endpoint: answers the n-th request with the n-th body.
final class _Server(
  final List<Stream<List<int>>> _bodies, {
  final int status = 200,
}) {
  final requests = <_Json>[];

  http.Client client() => MockClient.streaming((request, body) async {
    final sent = jsonDecode(utf8.decode(await body.toBytes())) as _Json;
    requests.add(sent);
    return http.StreamedResponse(_bodies[requests.length - 1], status);
  });
}

/// A screen with a counter the agent adds to, over [connection].
final class _Screen(AgentConnection connection, {TandemThread? thread}) {
  this {
    addTearDown(surface.close);
  }

  AgentConnection connection = connection;
  final surface = _Counter();
  final events = <TandemEvent>[];
  final TandemThread thread = thread ?? TandemThread();
  late TandemSession session;

  List<String> get agentTexts => [
    for (final message in session.items.whereType<AgentMessage>()) message.text,
  ];

  Future<void> mount(WidgetTester tester, {Widget child = const SizedBox()}) =>
      tester.pumpWidget(
        TandemScope.connected(
          surface: (context) => surface,
          connection: connection,
          thread: thread,
          approvals: const .fromState(),
          onEvent: (context, event, session) => events.add(event),
          child: Builder(
            builder: (context) {
              session = TandemSessionScope.of(context);
              return child;
            },
          ),
        ),
      );

  /// Presses Stop as soon as the agent's first text shows.
  void stopAtFirstText() {
    void stop() {
      if (agentTexts.isEmpty) return;
      session
        ..removeListener(stop)
        ..stop();
    }

    session.addListener(stop);
  }

  Future<void> settle(WidgetTester tester) => _pumpUntil(
    tester,
    () => session.status is Idle || session.status is AwaitingApproval,
  );
}

final class _Counter() implements AgentSurface {
  final _changes = StreamController<Object?>.broadcast();
  int value = 0;
  bool needsApproval = false;

  int add(int amount) {
    value += amount;
    _changes.add(value);
    return value;
  }

  Future<void> close() => _changes.close();

  @override
  Stream<Object?> get changes => _changes.stream;

  @override
  List<AgentCapability> get agentCapabilities => [
    .sees(value),
    if (needsApproval) .callsWithApproval(add) else .calls(add),
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

final class _NoteCatalog() implements AgentCatalog {
  @override
  List<AgentComponent> get components => [
    AgentComponent<Text>.of(
      name: 'Note',
      description: 'Shows a note.',
      properties: (_) => [],
      build: (_) => const Text('A note', textDirection: .ltr),
    ),
  ];

  @override
  String get guidelines => 'Leave a note.';

  @override
  List<_Json> get example => const [
    {'id': 'root', 'component': 'Note'},
  ];
}

/// Hands the session a run only once Firebase finished it, as a wrapper that
/// is not stoppable mid-run does.
final class _DeliversWholeRun(final FirebaseConnection _connection)
    implements StoppableAgentConnection {
  @override
  Stream<_Json> run(_Json input) async* {
    yield* Stream.fromIterable(await _connection.run(input).toList());
  }

  @override
  Future<void> stop(_Json input) => _connection.stop(input);
}

final class _PendingAppCheck(final Future<String?> _token)
    implements FirebaseAppCheck {
  @override
  Future<String?> getToken([bool? forceRefresh]) => _token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The first run of a thread, with a tool whose schema the SDK's typed
/// `Schema` cannot express.
_Json _firstRun() => {
  'threadId': 'thread',
  'runId': 'run',
  'state': <String, Object?>{},
  'messages': [
    {'id': 'user-1', 'role': 'user', 'content': 'Do both edits.'},
  ],
  'tools': [
    {'name': 'edit', 'description': 'Edit a value.', 'parameters': _schema},
  ],
  'context': [
    {'description': 'Current list', 'value': 'untrusted screen text'},
  ],
  'forwardedProps': <String, Object?>{},
};

const _schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'value': {
      'anyOf': [
        {'type': 'integer'},
        {'type': 'null'},
      ],
    },
  },
  'additionalProperties': false,
  'required': ['value'],
};

/// An answer as Gemini streams it with thinking on: a signed thought, text
/// around two calls, the second without an ID, and a signed empty part at
/// the end.
const _signedAnswer = <_Json>[
  {'text': 'Thinking', 'thought': true, 'thoughtSignature': 'thought'},
  {'text': 'I will add '},
  {'text': 'both.'},
  {
    'functionCall': {
      'name': 'add',
      'args': {'amount': 1},
      'id': 'native-a',
    },
    'thoughtSignature': 'call',
  },
  {'text': ' Then two.'},
  {
    'functionCall': {
      'name': 'add',
      'args': {'amount': 2},
    },
  },
  {'text': '', 'thoughtSignature': 'empty'},
];

const _addThree = <String, Object?>{
  'functionCall': {
    'name': 'add',
    'args': {'amount': 3},
    'id': 'native-add',
  },
  'thoughtSignature': 'call-signature',
};

_Json _signedViewCall(List<_Json> components) => {
  ..._call(
    'tandem_show_view',
    arguments: {'components': jsonEncode(components)},
    id: 'native-view',
  ),
  'thoughtSignature': 'view-signature',
};

const _viewShown = <String, Object?>{
  'functionResponse': {
    'name': 'tandem_show_view',
    'response': {
      'result': {'status': ToolStatus.shown},
    },
    'id': 'native-view',
  },
};

/// [part] as the SDK sends it back: its `UnknownPart` adds `thought`.
_Json _asSentBack(_Json part) => {'thought': false, ...part};

_Json _editCall(int value, {String? id}) =>
    _call('edit', arguments: {'value': value}, id: id ?? 'native-$value');

_Json _call(String name, {_Json arguments = const {}, required String id}) => {
  'functionCall': {'name': name, 'args': arguments, 'id': id},
};

_Json _addResult(Object? result, {String? id}) => {
  'functionResponse': {
    'name': 'add',
    'response': {'result': result},
    'id': ?id,
  },
};

Stream<List<int>> _reply(List<_Json> parts) => Stream.value(_chunk(parts));

/// One server-sent event of Firebase's stream, with a single candidate.
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

/// The chunk Firebase may still send after the finish reason.
final _usageOnly = utf8.encode(
  'data: ${jsonEncode({
    'usageMetadata': {'totalTokenCount': 12},
  })}\n\n',
);

Future<List<_Json>> _run(FirebaseConnection connection, _Server server) => http
    .runWithClient(() => connection.run(_firstRun()).toList(), server.client);

List<Object?> _types(List<_Json> events) => [
  for (final event in events) event['type'],
];

List<_Json> _ofType(List<_Json> events, String type) => [
  for (final event in events)
    if (event['type'] == type) event,
];

List<_Json> _contents(_Json request) => switch (request['contents']) {
  final List<Object?> contents => contents.cast(),
  _ => fail('The request has no contents.'),
};

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100; frame++) {
    await tester.runAsync(() => pumpEventQueue(times: 2));
    await tester.pump(const Duration(milliseconds: 10));
    if (ready()) return;
  }
  fail('The session did not reach the expected state.');
}
