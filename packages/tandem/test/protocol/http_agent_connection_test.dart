import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';

const _recordedChunkSize = 7;
const _pastIdleTimeout = Duration(seconds: 61);

void main() {
  test('streams a recorded ag-ui-adk run', () async {
    final endpoint = Uri.parse('http://localhost:8000/agent');
    final input = <String, Object?>{
      'threadId': 'thread-A',
      'runId': 'run-A1',
      'messages': <Object?>[],
    };
    final recorded = File('test/protocol/a1.sse').readAsBytesSync();
    late http.BaseRequest sent;
    late Object? sentBody;
    final client = MockClient.streaming((request, bodyStream) async {
      sent = request;
      sentBody = jsonDecode(await bodyStream.bytesToString());
      return http.StreamedResponse(
        Stream.fromIterable([
          for (var i = 0; i < recorded.length; i += _recordedChunkSize)
            recorded.skip(i).take(_recordedChunkSize).toList(),
        ]),
        200,
      );
    });

    final events = await HttpAgentConnection(
      endpoint,
      client: client,
    ).run(input).toList();

    expect(sent.method, 'POST');
    expect(sent.url, endpoint);
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

    HttpAgentConnection(
          Uri.parse('http://localhost:8000/agent'),
          client: client,
        )
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

    HttpAgentConnection(
          Uri.parse('http://localhost:8000/agent'),
          client: client,
        )
        .run(const {})
        .listen(null, onError: errors.add, onDone: () => done = true);
    await tester.pump(_pastIdleTimeout);

    expect(errors, [isA<TimeoutException>()]);
    expect(done, isTrue);
  });
}
