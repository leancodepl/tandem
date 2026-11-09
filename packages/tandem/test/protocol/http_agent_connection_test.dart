import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/src/protocol/agent_connection.dart';

const _pastIdleTimeout = Duration(seconds: 61);

final _endpoint = Uri.parse('http://localhost:8000/agent');

// Ending a stream needs root-zone microtasks, which the fake clock skips.
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 2; round++) {
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
  }
}

final class _SpyClient(super.handler) extends MockClient {
  this : super.streaming();

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test('skips replayed runs before the requested run', () async {
    final replay = [
      {'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-old'},
      {
        'type': 'MESSAGES_SNAPSHOT',
        'messages': [
          {'id': 'm1', 'role': 'assistant', 'content': 'Already said.'},
          {
            'id': 'asst-c1',
            'role': 'assistant',
            'toolCalls': [
              {
                'id': 'c1',
                'type': 'function',
                'function': {'name': 'add', 'arguments': '{"item":"milk"}'},
              },
            ],
          },
        ],
      },
      {'type': 'RUN_ERROR', 'message': 'Old'},
      {'type': 'RUN_STARTED', 'threadId': 'thread-B', 'runId': 'run-current'},
      {'type': 'RUN_FINISHED'},
      {'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-current'},
      {'type': 'TEXT_MESSAGE_CHUNK', 'messageId': 'm2', 'delta': 'Next.'},
      {
        'type': 'TOOL_CALL_CHUNK',
        'toolCallId': 'c2',
        'toolCallName': 'add',
        'delta': '{"item":"eggs"}',
      },
      {'type': 'RUN_FINISHED'},
    ];
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            [for (final event in replay) 'data: ${jsonEncode(event)}\n\n']
                .join(),
          ),
        ),
        200,
      ),
    );

    final events = await HttpAgentConnection(
      _endpoint,
      client: client,
    ).run({'threadId': 'thread-A', 'runId': 'run-current'}).toList();

    expect(events, [
      replay[5],
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm2', 'delta': 'Next.'},
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c2', 'toolCallName': 'add'},
      {
        'type': 'TOOL_CALL_ARGS',
        'toolCallId': 'c2',
        'delta': '{"item":"eggs"}',
      },
      replay.last,
    ]);
  });

  test('skips an opening error that names another thread or run', () async {
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"type":"RUN_ERROR","threadId":"thread-A",'
            '"runId":"run-old","message":"Old failure"}\n\n'
            'data: {"type":"RUN_ERROR","threadId":"thread-B",'
            '"runId":"run-current","message":"Other thread"}\n\n'
            'data: {"type":"RUN_STARTED","threadId":"thread-A",'
            '"runId":"run-current"}\n\n'
            'data: {"type":"RUN_FINISHED"}\n\n',
          ),
        ),
        200,
      ),
    );

    final events = await HttpAgentConnection(
      _endpoint,
      client: client,
    ).run({'threadId': 'thread-A', 'runId': 'run-current'}).toList();

    expect(events, [
      {'type': 'RUN_STARTED', 'threadId': 'thread-A', 'runId': 'run-current'},
      {'type': 'RUN_FINISHED'},
    ]);
  });

  test('reports a run error before the requested run starts', () async {
    const error = {'type': 'RUN_ERROR', 'message': 'Unavailable'};
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.value(utf8.encode('data: ${jsonEncode(error)}\n\n')),
        200,
      ),
    );

    await expectLater(
      HttpAgentConnection(
        _endpoint,
        client: client,
      ).run({'threadId': 'thread-A', 'runId': 'run-current'}),
      emitsInOrder([error, emitsDone]),
    );
  });

  test('a run ends at RUN_FINISHED while the server keeps the connection '
      'open', () async {
    var sourceCancelled = false;
    final source =
        StreamController<List<int>>(onCancel: () => sourceCancelled = true)
          ..add(
            utf8.encode(
              'data: {"type":"RUN_STARTED"}\n\n'
              'data: {"type":"RUN_FINISHED"}\n\n'
              'data: {"type":"RUN_STARTED"}\n\n',
            ),
          );
    final client = _SpyClient(
      (request, bodyStream) async => http.StreamedResponse(source.stream, 200),
    );

    // Without a client of its own, the connection opens one and closes it.
    final events = await http.runWithClient(
      () => HttpAgentConnection(_endpoint).run(const {}).toList(),
      () => client,
    );

    expect(
      [for (final event in events) event['type']],
      ['RUN_STARTED', 'RUN_FINISHED'],
    );
    expect(sourceCancelled, isTrue);
    expect(client.closed, isTrue);
  });

  test('a run ends at RUN_ERROR while the server keeps the connection '
      'open', () async {
    var sourceCancelled = false;
    final source =
        StreamController<List<int>>(onCancel: () => sourceCancelled = true)
          ..add(
            utf8.encode(
              'data: {"type":"RUN_STARTED"}\n\n'
              'data: {"type":"RUN_ERROR","message":"Quota exceeded"}\n\n'
              'data: {"type":"TEXT_MESSAGE_CHUNK","messageId":"m1","delta":"A"}'
              '\n\n',
            ),
          );
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(source.stream, 200),
    );

    await expectLater(
      HttpAgentConnection(_endpoint, client: client).run(const {}),
      emitsInOrder([
        {'type': 'RUN_STARTED'},
        {'type': 'RUN_ERROR', 'message': 'Quota exceeded'},
        emitsDone,
      ]),
    );
    expect(sourceCancelled, isTrue);
  });

  test('cancelling a run waits for the connection to clean up', () async {
    final cleanup = Completer<void>();
    final source = StreamController<List<int>>(onCancel: () => cleanup.future)
      ..add(utf8.encode('data: {"type":"RUN_STARTED"}\n\n'));
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(source.stream, 200),
    );
    final started = Completer<void>();
    final subscription = HttpAgentConnection(
      _endpoint,
      client: client,
    ).run(const {}).listen((event) => started.complete());
    await started.future;
    var cancelled = false;

    final cancelling = subscription.cancel().then((_) => cancelled = true);
    await pumpEventQueue();
    expect(cancelled, isFalse);

    cleanup.complete();
    await cancelling;
    expect(cancelled, isTrue);
  });

  testWidgets('cancelling while the headers are pending aborts the request', (
    tester,
  ) async {
    var aborted = false;
    final client = _SpyClient((request, bodyStream) async {
      // MockClient never aborts on its own: the handler waits for the trigger.
      await switch (request) {
        http.Abortable(:final abortTrigger?) => abortTrigger,
        _ => Completer<void>().future,
      };
      aborted = true;
      throw http.RequestAbortedException();
    });
    final subscription = HttpAgentConnection(
      _endpoint,
      client: client,
    ).run(const {}).listen(null);
    await tester.pump();
    var cancelled = false;

    unawaited(subscription.cancel().then((_) => cancelled = true));
    // The end of a cancelled stream waits for a root-zone microtask.
    await tester.runAsync(() => Future<void>.delayed(.zero));
    await tester.pump();

    expect(cancelled, isTrue);
    expect(aborted, isTrue);
    expect(client.closed, isFalse);
  });

  testWidgets('a silent connection ends with an error and is cancelled', (
    tester,
  ) async {
    var sourceCancelled = false;
    final source = StreamController<List<int>>(
      onCancel: () => sourceCancelled = true,
    )..add(utf8.encode('data: {"type":"RUN_STARTED"}\n\n'));
    final client = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(source.stream, 200),
    );
    final events = <Map<String, Object?>>[];
    final errors = <Object>[];
    var done = false;

    HttpAgentConnection(_endpoint, client: client)
        .run(const {})
        .listen(events.add, onError: errors.add, onDone: () => done = true);
    await tester.pump(_pastIdleTimeout);
    await _settle(tester);

    expect(events, [
      {'type': 'RUN_STARTED'},
    ]);
    expect(errors, [isA<TimeoutException>()]);
    expect(done, isTrue);
    expect(sourceCancelled, isTrue);
  });

  testWidgets('a connection that never answers ends with an error', (
    tester,
  ) async {
    final client = MockClient.streaming(
      (request, bodyStream) => Completer<http.StreamedResponse>().future,
    );
    final errors = <Object>[];
    var done = false;

    HttpAgentConnection(_endpoint, client: client)
        .run(const {})
        .listen(null, onError: errors.add, onDone: () => done = true);
    await tester.pump(_pastIdleTimeout);
    await _settle(tester);

    expect(errors, [isA<TimeoutException>()]);
    expect(done, isTrue);
  });
}
