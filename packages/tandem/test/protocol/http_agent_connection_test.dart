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

Stream<Map<String, Object?>> _run(String name) {
  final client = MockClient.streaming(
    (request, bodyStream) async => _fixture(name),
  );

  return HttpAgentConnection(_endpoint, client: client).run(const {});
}

Future<List<AgentEvent>> _agentEvents(String name) async => [
  for (final json in await _run(name).toList()) AgentEvent.fromJson(json),
];

Map<String, String> _texts(List<AgentEvent> events) {
  final texts = <String, String>{};
  for (final event in events) {
    if (event case TextDelta(:final messageId, :final delta)) {
      texts.update(messageId, (text) => '$text$delta', ifAbsent: () => delta);
    }
  }
  return texts;
}

Map<String, String> _arguments(List<AgentEvent> events) {
  final arguments = <String, String>{};
  for (final event in events) {
    if (event case ToolCallArgs(:final toolCallId, :final delta)) {
      arguments.update(
        toolCallId,
        (json) => '$json$delta',
        ifAbsent: () => delta,
      );
    }
  }
  return arguments;
}

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
    final events = await _agentEvents('ag_ui_chunk_events.sse');

    final texts = events.whereType<TextDelta>();
    final started = events.whereType<ToolCallStarted>().single;
    final args = events.whereType<ToolCallArgs>();
    expect(texts.map((text) => text.delta).join(), 'Hello');
    expect(texts.map((text) => text.messageId).toSet(), {'msg-1'});
    expect(started.name, 'add');
    expect(args.map((arg) => arg.delta).join(), '{"item":"milk"}');
    expect(args.map((arg) => arg.toolCallId).toSet(), {started.toolCallId});
  });

  test('chunks of a parent and two subagents continue their own message and '
      'call', () async {
    final events = await _agentEvents('ag_ui_chunk_lanes.sse');

    expect(_texts(events), {'p1': 'XY', 'm1': 'AC', 'm2': 'BD'});
    expect(
      [for (final call in events.whereType<ToolCallStarted>()) call.toolCallId],
      ['c1', 'c2'],
    );
    expect(_arguments(events), {
      'c1': '{"item":"milk"}',
      'c2': '{"item":"eggs"}',
    });
  });

  test('a subagent that opens a call closes its message, so a chunk without '
      'an id continues the only message left open', () async {
    final events = await _agentEvents('ag_ui_chunk_text_to_call.sse');

    expect(_texts(events), {'m1': 'Looking up.', 'm2': 'Result'});
    expect(_arguments(events), {'c1': '{}'});
    expect(events.last, isA<RunFinished>());
  });

  test('a subagent that opens a message closes its call, so chunks continue '
      'the only call left open', () async {
    final events = await _agentEvents('ag_ui_chunk_call_to_text.sse');

    expect(_texts(events), {'m1': 'Found it.'});
    expect(
      [for (final call in events.whereType<ToolCallStarted>()) call.toolCallId],
      ['c1', 'c2'],
    );
    expect(_arguments(events), {'c1': '{}', 'c2': '{"item":"milk"}'});
    expect(events.last, isA<RunFinished>());
  });

  test('a subagent that finishes or fails closes its message, so a chunk '
      'without an id continues the only message left open', () async {
    final events = await _agentEvents('ag_ui_chunk_subagent_end.sse');

    expect(_texts(events), {'m1': 'Found.', 'm2': 'Failed.', 'm3': 'Result'});
    expect(events.last, isA<RunFinished>());
  });

  test('an event of a sender closes its call and MESSAGES_SNAPSHOT closes '
      'every call, so chunks continue the only call left open', () async {
    final events = await _agentEvents('ag_ui_chunk_closing_events.sse');

    expect(_arguments(events), {
      'pc': '{}',
      'c1': '{"item":"milk"}',
      'c2': '{"item":"eggs"}',
    });
    expect(events.last, isA<RunFinished>());
  });

  test('a reasoning message that a sender opens closes its message, and one '
      'that goes on by its id closes nothing', () async {
    final events = await _agentEvents('ag_ui_chunk_reasoning.sse');

    expect(_texts(events), {'p1': 'Checking. Done.', 'm1': 'Result'});
    expect(events.last, isA<RunFinished>());
  });

  test('an ambiguous chunk fails the stream, as malformed JSON does', () async {
    await expectLater(
      _run('ag_ui_chunk_ambiguous.sse'),
      emitsInOrder([
        {'type': 'RUN_STARTED', 'threadId': 'thread-C', 'runId': 'run-C1'},
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1', 'delta': 'A'},
        {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm2', 'delta': 'B'},
        emitsError(isFormatException),
      ]),
    );
    await expectLater(
      _run('ag_ui_chunk_ambiguous_call.sse'),
      emitsInOrder([
        {'type': 'RUN_STARTED', 'threadId': 'thread-C', 'runId': 'run-C1'},
        {'type': 'TOOL_CALL_START', 'toolCallId': 'c1', 'toolCallName': 'add'},
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': '{"item":'},
        {'type': 'TOOL_CALL_START', 'toolCallId': 'c2', 'toolCallName': 'add'},
        {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c2', 'delta': '{"item":'},
        emitsError(isFormatException),
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
