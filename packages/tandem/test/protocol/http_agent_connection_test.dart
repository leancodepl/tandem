import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';

const _fixtureChunkSize = 7;
const _pastIdleTimeout = Duration(seconds: 61);

final _endpoint = Uri.parse('http://localhost:8000/agent');

/// The response whose body is the file [name] of the fixtures, in pieces that
/// cut its lines and characters.
http.StreamedResponse _fixture(String name) {
  final bytes = File('test/protocol/$name').readAsBytesSync();
  return http.StreamedResponse(
    Stream.fromIterable([
      for (var i = 0; i < bytes.length; i += _fixtureChunkSize)
        bytes.skip(i).take(_fixtureChunkSize).toList(),
    ]),
    200,
  );
}

/// A client that remembers whether it was closed.
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
  test('streams a recorded ag-ui-adk run', () async {
    final input = <String, Object?>{
      'threadId': 'thread-A',
      'runId': 'run-A1',
      'messages': <Object?>[],
    };
    late http.BaseRequest sent;
    late Object? sentBody;
    final client = MockClient.streaming((request, bodyStream) async {
      sent = request;
      sentBody = jsonDecode(await bodyStream.bytesToString());
      // Recorded from ag-ui-adk 0.9.0 with a scripted model, 2026-10-16.
      return _fixture('adk_transfer_tool_calls.sse');
    });

    final events = await HttpAgentConnection(
      _endpoint,
      client: client,
    ).run(input).toList();

    expect(sent.method, 'POST');
    expect(sent.url, _endpoint);
    expect(sent.headers, {
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
    });
    expect(sentBody, input);
    expect(
      [for (final event in events) event['type']],
      [
        'RUN_STARTED',
        'TOOL_CALL_START',
        'TOOL_CALL_ARGS',
        'TOOL_CALL_END',
        'TOOL_CALL_RESULT',
        'STATE_DELTA',
        'TOOL_CALL_START',
        'TOOL_CALL_ARGS',
        'STATE_SNAPSHOT',
        'TOOL_CALL_END',
        'RUN_FINISHED',
      ],
    );
    expect(
      AgentEvent.fromJson(events[6]),
      isA<ToolCallStarted>()
          .having(
            (event) => event.toolCallId,
            'toolCallId',
            'adk-0b70724d-6757-4c4a-ab32-4574550ba0ef',
          )
          .having((event) => event.name, 'name', 'request_transfer'),
    );
  });

  test('decodes the chunk events of the AG-UI specification', () async {
    final client = MockClient.streaming(
      (request, bodyStream) async => _fixture('ag_ui_chunk_events.sse'),
    );

    final events = [
      for (final json in await HttpAgentConnection(
        _endpoint,
        client: client,
      ).run(const {}).toList())
        AgentEvent.fromJson(json),
    ];

    final texts = events.whereType<TextDelta>();
    final started = events.whereType<ToolCallStarted>().single;
    final args = events.whereType<ToolCallArgs>();
    expect(texts.map((text) => text.delta).join(), 'Hello');
    expect(texts.map((text) => text.messageId).toSet(), {'msg-1'});
    expect(started.name, 'add');
    expect(args.map((arg) => arg.delta).join(), '{"item":"milk"}');
    expect(args.map((arg) => arg.toolCallId).toSet(), {started.toolCallId});
  });

  test('a run ends at RUN_FINISHED while the server keeps the connection '
      'open', () async {
    var sourceCancelled = false;
    // One more event follows RUN_FINISHED in the same bytes.
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

  testWidgets('cancelling while the headers are pending aborts the request', (
    tester,
  ) async {
    var aborted = false;
    final client = _SpyClient((request, bodyStream) async {
      // A MockClient never aborts by itself: the handler has to. A request
      // that cannot be aborted waits for ever.
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
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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
    // The end of a cancelled stream waits for a root-zone microtask.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

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

    expect(errors, [isA<TimeoutException>()]);
    expect(done, isTrue);
  });
}
