import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/protocol/events.dart';

const _recordedChunkSize = 7;

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
}
