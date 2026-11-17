import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/src/errors.dart';
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
  test(
    'a response that is not an AG-UI stream fails with what it lacks',
    () async {
      final cases = {
        '<!doctype html><title>Sign in</title>': 'It had no AG-UI event.',
        'data: [1]\n\n': 'An AG-UI event is a JSON object',
      };

      for (final MapEntry(key: body, value: message) in cases.entries) {
        final client = MockClient(
          (request) async =>
              http.Response(body, 200, headers: {'content-type': 'text/html'}),
        );

        await expectLater(
          HttpAgentConnection(
            _endpoint,
            client: client,
          ).run({'threadId': 'thread-A', 'runId': 'run-current'}),
          emitsInOrder([
            emitsError(
              isFormatException.having(
                (error) => error.message,
                'message',
                contains(message),
              ),
            ),
            emitsDone,
          ]),
          reason: body,
        );
      }
    },
  );

  test('a status other than 200 fails the run with the body', () async {
    final client = MockClient(
      (request) async => http.Response('messages: field required', 422),
    );

    await expectLater(
      HttpAgentConnection(_endpoint, client: client).run(const {}),
      emitsInOrder([
        emitsError(
          isA<AgentHttpException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having(
                (error) => error.body,
                'body',
                'messages: field required',
              ),
        ),
        emitsDone,
      ]),
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

  testWidgets('a connection silent for its idle timeout ends with an error '
      'and is cancelled', (tester) async {
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

    HttpAgentConnection(
          _endpoint,
          client: client,
          idleTimeout: const Duration(seconds: 5),
        )
        .run(const {})
        .listen(events.add, onError: errors.add, onDone: () => done = true);
    await tester.pump(const Duration(seconds: 6));
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
