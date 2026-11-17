import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem_firebase_ai/src/firebase_request.dart';
import 'package:tandem_firebase_ai/src/firebase_runs.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  late FirebaseAI firebase;
  setUpAll(() async {
    firebase = FirebaseAI.googleAI(app: await Firebase.initializeApp());
  });
  tearDown(() => firebase.appCheck = null);

  test('SDK roundtrip preserves signed ordered parts, raw schemas and parallel results', () async {
    final requests = <JsonObject>[];
    final connection = FirebaseConnection(
      firebase: firebase,
      model: 'test-model',
      instructions: 'Only edit on request.',
    );
    http.Client client() => MockClient((request) async {
      requests.add(_json(request.body));
      return http.Response(_sse([_wire(_signedParts)]), 200);
    });
    final first = await _run(connection, _input(), client);
    expect(first.last['type'], 'RUN_FINISHED');
    expect(_events(first, 'TOOL_CALL_START'), hasLength(2));
    final assistant = _assistant(first);
    final calls = _objects(assistant['toolCalls']);
    final next = _input(
      messages: [
        _user,
        assistant,
        for (final (index, call) in calls.indexed)
          {
            'role': 'tool',
            'toolCallId': call['id'],
            'content': index == 0 ? 'null' : '{"status":"rejected_by_user"}',
          },
      ],
    );
    next['context'] = [
      {'description': 'app_notes', 'value': 'fresh screen data'},
    ];
    await _run(connection, next, client);
    final contents = _objects(requests.last['contents']);
    expect(contents.first['parts'], [
      {'text': _user['content']},
    ]);
    expect(contents[1]['parts'], [
      for (final part in _signedParts) {'thought': false, ...part},
    ]);
    expect(contents[2], {
      'role': 'user',
      'parts': [
        {
          'functionResponse': {
            'name': 'edit',
            'id': 'native-a',
            'response': {'result': null},
          },
        },
        {
          'functionResponse': {
            'name': 'edit',
            'id': 'native-b',
            'response': {
              'result': {'status': 'rejected_by_user'},
            },
          },
        },
        {'text': contains('fresh screen data')},
      ],
    });
    final declarations = _objects(
      _objects(requests.first['tools']).single['functionDeclarations'],
    );
    expect(declarations.single['parametersJsonSchema'], _schema);
    expect(_objects(requests.first['contents']).single, {
      'role': 'user',
      'parts': [
        {'text': _user['content']},
        {'text': contains('untrusted screen text')},
      ],
    });
    final system = _object(requests.first['systemInstruction']);
    expect(system, requests.last['systemInstruction']);
    expect(
      _objects(system['parts']).single['text'],
      allOf(
        contains('Only edit on request.'),
        isNot(contains('untrusted screen text')),
        isNot(contains('fresh screen data')),
      ),
    );
  });

  for (final (label, parts) in [
    (
      'unknown name',
      [const FunctionCall('edit', {}), const FunctionCall('unknown', {})],
    ),
    (
      'duplicate provider ID',
      [
        const FunctionCall('edit', {'n': 1}, id: 'same'),
        const FunctionCall('edit', {'n': 2}, id: 'same'),
      ],
    ),
  ]) {
    test('rejects the whole batch for $label', () async {
      final runs = _fakeRuns((_, _) => Stream.value(_response(parts)));
      final events = await runs.run(_input()).toList();
      expect(_events(events, 'TOOL_CALL_START'), isEmpty);
      expect(
        events.last,
        containsPair('code', FirebaseErrorCode.invalidResponse),
      );
    });
  }

  for (final (reason, code) in [
    ('SAFETY', FirebaseErrorCode.blocked),
    ('RECITATION', FirebaseErrorCode.blocked),
    ('MAX_TOKENS', FirebaseErrorCode.outputLimit),
    ('MODEL_ARMOR', FirebaseErrorCode.generationFailed),
  ]) {
    test('drops the failed $reason chunk even when followed by STOP', () async {
      final chunks = [
        _wire(_signedParts, finishReason: reason),
        _wire([
          {'text': 'too late'},
        ]),
      ];
      final events = await _run(
        FirebaseConnection(firebase: firebase, model: 'test-model'),
        _input(),
        () => MockClient((_) async => http.Response(_sse(chunks), 200)),
      );
      expect(events.map((event) => event['type']), [
        'RUN_STARTED',
        'RUN_ERROR',
      ]);
      expect(events.last['code'], code);
    });
  }

  test('calls require an explicit successful finish', () async {
    final runs = _fakeRuns(
      (_, _) => Stream.value(
        _response([const FunctionCall('edit', {})], reason: null),
      ),
    );
    final events = await runs.run(_input()).toList();
    expect(events.map((event) => event['type']), ['RUN_STARTED', 'RUN_ERROR']);
    expect(events.last['code'], FirebaseErrorCode.generationFailed);
  });

  test('malformed SDK function arguments reject the whole batch', () async {
    final chunk = _wire([
      ..._signedParts,
      {
        'functionCall': {'name': 'edit', 'args': 'malformed'},
      },
    ]);
    final events = await _run(
      FirebaseConnection(firebase: firebase, model: 'test-model'),
      _input(),
      () => MockClient((_) async => http.Response(_sse([chunk]), 200)),
    );
    expect(events.map((event) => event['type']), ['RUN_STARTED', 'RUN_ERROR']);
    expect(events.last['code'], FirebaseErrorCode.invalidResponse);
  });

  test('a transport failure stays a generation failure', () async {
    final events = await _run(
      FirebaseConnection(firebase: firebase, model: 'test-model'),
      _input(),
      () => MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.error(const FormatException('transport')),
          200,
        ),
      ),
    );
    expect(events.last['code'], FirebaseErrorCode.generationFailed);
  });

  test(
    'Stop before App Check completes returns promptly and prevents a late send',
    () async {
      final token = Completer<String?>();
      firebase.appCheck = _PendingAppCheck(token.future);
      var sends = 0;
      final connection = FirebaseConnection(
        firebase: firebase,
        model: 'test-model',
      );
      http.Client client() => MockClient((_) async {
        sends++;
        return http.Response(
          _sse([
            _wire([
              {'text': 'late'},
            ]),
          ]),
          200,
        );
      });
      final input = _input();
      final finished = _run(connection, input, client);
      await Future<void>.delayed(Duration.zero);
      await connection.stop(input);
      final events = await finished.timeout(const Duration(seconds: 1));
      expect(events.last['outcome'], {'type': 'cancelled'});
      token.complete('fake-token');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(sends, 0);
      await connection.stop(input);
    },
  );

  test('stream cancellation before token completion closes locally without a late send', () async {
    final token = Completer<String?>();
    firebase.appCheck = _PendingAppCheck(token.future);
    var sends = 0;
    final connection = FirebaseConnection(
      firebase: firebase,
      model: 'test-model',
    );
    http.Client client() => MockClient((_) async {
      sends++;
      return http.Response('{}', 200);
    });
    final subscription = http.runWithClient(
      () => connection.run(_input()).listen((_) {}),
      client,
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel().timeout(const Duration(seconds: 1));
    token.complete('fake-token');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(sends, 0);
  });

  test('stopping one session leaves concurrent sessions running', () async {
    final streams = [
      StreamController<GenerateContentResponse>(),
      StreamController<GenerateContentResponse>(),
    ];
    var index = 0;
    final runs = _fakeRuns((_, _) => streams[index++].stream);
    final first = _input();
    final second = _input();
    final firstDone = runs.run(first).toList();
    final secondDone = runs.run(second).toList();
    await runs.stop(first);
    streams[1].add(_response([const TextPart('second')]));
    await streams[1].close();
    expect((await firstDone).last['outcome'], {'type': 'cancelled'});
    final events = await secondDone;
    expect(_events(events, 'TEXT_MESSAGE_CONTENT').single['delta'], 'second');
    expect(events.last['type'], 'RUN_FINISHED');
    await streams[0].close();
  });

  test('changed tool history is rejected, while a shortened text turn keeps only visible text', () async {
    final seen = <FirebaseRequest>[];
    final runs = _fakeRuns((request, _) {
      seen.add(request);
      return Stream.value(
        _response([
          const TextPart('whole answer'),
          const FunctionCall('edit', {}, id: 'native'),
        ]),
      );
    });
    final first = _assistant(await runs.run(_input()).toList());
    final calls = _objects(first['toolCalls']);
    final result = {
      'role': 'tool',
      'toolCallId': calls.single['id'],
      'content': 'null',
    };
    final incompatible = await runs
        .run(
          _input(
            messages: [
              _user,
              {...first, 'content': 'whole'},
              result,
            ],
          ),
        )
        .toList();
    expect(incompatible.last['code'], FirebaseErrorCode.incompatibleHistory);
    expect(seen, hasLength(1));

    await runs
        .run(
          _input(
            messages: [
              _user,
              {...first, 'content': 'whole', 'toolCalls': <Object?>[]},
              _user,
            ],
          ),
        )
        .drain<void>();
    expect(seen.last.contents[1].toJson(), {
      'role': 'model',
      'parts': [
        {'text': 'whole'},
      ],
    });
  });

  test(
    'replacement connection cannot replay another connection tool history',
    () async {
      Stream<GenerateContentResponse> generate(
        FirebaseRequest _,
        http.Client _,
      ) => Stream.value(
        _response([const FunctionCall('edit', {}, id: 'native')]),
      );
      final first = _assistant(
        await _fakeRuns(generate).run(_input()).toList(),
      );
      final call = _objects(first['toolCalls']).single;
      final result = await _fakeRuns(generate)
          .run(
            _input(
              messages: [
                _user,
                first,
                {'role': 'tool', 'toolCallId': call['id'], 'content': 'null'},
              ],
            ),
          )
          .toList();
      expect(result.last['code'], FirebaseErrorCode.incompatibleHistory);
    },
  );

  test('timeouts include credential acquisition', () async {
    final token = Completer<String?>();
    firebase.appCheck = _PendingAppCheck(token.future);
    final connection = FirebaseConnection(
      firebase: firebase,
      model: 'test-model',
      idleTimeout: const Duration(milliseconds: 10),
    );
    final events = await _run(
      connection,
      _input(),
      () => MockClient((_) async => http.Response('{}', 200)),
    );
    expect(events.last['code'], FirebaseErrorCode.timedOut);
    expect(
      events.last['message'],
      'Timed out waiting for Firebase credentials.',
    );
    token.complete('fake-token');
    await Future<void>.delayed(Duration.zero);
  });

  test('native config rejects unsupported response modes before a request', () {
    expect(
      () => FirebaseConnection(
        firebase: firebase,
        model: 'test',
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.image],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => FirebaseConnection(
        firebase: firebase,
        model: 'test',
        idleTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test(
    'a later change to response modalities cannot send an image request',
    () async {
      final modalities = [ResponseModalities.text];
      final connection = FirebaseConnection(
        firebase: firebase,
        model: 'test',
        generationConfig: GenerationConfig(responseModalities: modalities),
      );
      modalities.add(ResponseModalities.image);
      var sends = 0;
      final events = await _run(
        connection,
        _input(),
        () => MockClient((_) async {
          sends++;
          return http.Response('{}', 200);
        }),
      );
      expect(events.last['code'], FirebaseErrorCode.invalidInput);
      expect(sends, 0);
    },
  );

  test('unreadable native output becomes an explicit run error', () async {
    final runs = _fakeRuns(
      (_, _) => Stream.value(
        _response([
          UnknownPart({'newOutputKind': 'value'}),
        ]),
      ),
    );
    final events = await runs.run(_input()).toList();
    expect(events.last['code'], FirebaseErrorCode.unsupportedResponse);
    expect(_events(events, 'RUN_FINISHED'), isEmpty);
  });
}

Future<List<JsonObject>> _run(
  FirebaseConnection connection,
  JsonObject input,
  http.Client Function() client,
) => http.runWithClient(() => connection.run(input).toList(), client);

JsonObject _object(Object? value) => switch (value) {
  final JsonObject object => object,
  _ => throw StateError('Expected a JSON object.'),
};

List<JsonObject> _objects(Object? value) => switch (value) {
  final List<Object?> list => list.map(_object).toList(),
  _ => throw StateError('Expected a JSON array.'),
};

FirebaseRuns _fakeRuns(Generate generate) => FirebaseRuns(
  generate: generate,
  instructions: '',
  idleTimeout: const Duration(seconds: 1),
);

const _user = <String, Object?>{'role': 'user', 'content': 'Do both edits.'};
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
JsonObject _input({List<JsonObject>? messages}) => {
  'threadId': 'thread',
  'runId': 'run',
  'messages': messages ?? [_user],
  'tools': [
    {'name': 'edit', 'description': 'Edit a value.', 'parameters': _schema},
  ],
  'context': [
    {'description': 'Current list', 'value': 'untrusted screen text'},
  ],
};

GenerateContentResponse _response(
  List<Part> parts, {
  FinishReason? reason = FinishReason.stop,
}) => GenerateContentResponse([
  Candidate(Content.model(parts), null, null, reason, null),
], null);
JsonObject _wire(List<JsonObject> parts, {String finishReason = 'STOP'}) => {
  'candidates': [
    {
      'content': {'role': 'model', 'parts': parts},
      'finishReason': finishReason,
    },
  ],
};
String _sse(List<JsonObject> chunks) =>
    chunks.map((chunk) => 'data: ${jsonEncode(chunk)}\n\n').join();
JsonObject _json(String text) =>
    (jsonDecode(text) as Map).cast<String, Object?>();
List<JsonObject> _events(List<JsonObject> events, String type) =>
    events.where((event) => event['type'] == type).toList();

JsonObject _assistant(List<JsonObject> events) => {
  'role': 'assistant',
  'content': _events(
    events,
    'TEXT_MESSAGE_CONTENT',
  ).map((event) => event['delta']).join(),
  'metadata': _events(events, 'TEXT_MESSAGE_END').single['metadata'],
  'toolCalls': [
    for (final start in _events(events, 'TOOL_CALL_START'))
      {
        'id': start['toolCallId'],
        'function': {
          'name': start['toolCallName'],
          'arguments': _events(events, 'TOOL_CALL_ARGS')
              .where((args) => args['toolCallId'] == start['toolCallId'])
              .single['delta'],
        },
      },
  ],
};

const _signedParts = <JsonObject>[
  {'text': 'Thinking', 'thought': true, 'thoughtSignature': 'thought'},
  {'text': 'I will edit '},
  {'text': 'both.'},
  {
    'functionCall': {
      'name': 'edit',
      'args': {'value': 1},
      'id': 'native-a',
    },
    'thoughtSignature': 'call',
  },
  {'text': 'Second edit.'},
  {
    'functionCall': {
      'name': 'edit',
      'args': {'value': 2},
      'id': 'native-b',
    },
  },
  {'text': '', 'thoughtSignature': 'empty'},
];

final class _PendingAppCheck(final Future<String?> token)
    implements FirebaseAppCheck {
  @override
  Future<String?> getToken([bool? forceRefresh]) => token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
