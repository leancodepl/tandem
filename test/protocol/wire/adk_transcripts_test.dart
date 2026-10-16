import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';

import '../fixtures/ag_ui_adk.dart';

void main() {
  group('WireEvent.fromJson on real ag-ui-adk streams', () {
    final names = AgUiAdkTranscripts.names;

    test('finds the transcripts', () {
      expect(names, hasLength(46));
      expect(names, containsAll(['A1', 'G3', 'H2', 'M1', 'slow']));
    });

    test('decodes all 383 events to typed events and keeps their JSON', () {
      var count = 0;
      for (final name in names) {
        for (final json in AgUiAdkTranscripts.frames(name)) {
          final event = WireEvent.fromJson(json);
          expect(event, isNot(isA<UnknownEvent>()), reason: '$name: $json');
          expect(event.json, same(json));
          expect(event.type, json['type']);
          count++;
        }
      }
      expect(count, 383);
    });

    test('reads a backend tool, a state delta and a frontend tool call', () {
      final events = _decode('A1');

      expect(events.map((event) => event.type), [
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
      ]);

      final started = events[0] as RunStarted;
      expect(started.threadId, 'thread-A');
      expect(started.runId, 'run-A1');
      expect(started.json['protocolVersion'], '1.0');

      final backendCall = events[1] as ToolCallStart;
      expect(backendCall.toolCallName, 'update_transfer');
      expect(backendCall.parentMessageId, isNull);

      final args = events[2] as ToolCallArgs;
      expect(args.toolCallId, backendCall.toolCallId);
      expect(jsonDecode(args.delta), {
        'amount': 250.0,
        'title': 'Rent October',
      });

      expect((events[3] as ToolCallEnd).toolCallId, backendCall.toolCallId);

      final result = events[4] as ToolCallResult;
      expect(result.toolCallId, backendCall.toolCallId);
      expect(result.messageId, '96ddd530-85b3-43fa-a6f6-5af8b6c5e37f');
      expect(jsonDecode(result.content), containsPair('status', 'updated'));

      final delta = events[5] as StateDelta;
      expect(delta.operations, [
        {
          'op': 'add',
          'path': '/transfer',
          'value': {
            'recipient': 'Anna Kowalska',
            'iban': 'PL61109010140000071219812874',
            'amount': 250.0,
            'title': 'Rent October',
          },
        },
      ]);

      expect((events[6] as ToolCallStart).toolCallName, 'request_transfer');

      final snapshot = events[8] as StateSnapshot;
      expect(
        snapshot.snapshot.keys,
        containsAll(['transfer', '_ag_ui_thread_id', '_ag_ui_user_id']),
      );
    });

    test('reads a tool call without arguments and keeps the outcome', () {
      final events = _decode('H2');

      // execute_transfer has no arguments, so START is followed by END.
      expect(events[1], isA<ToolCallStart>());
      expect(events[2], isA<ToolCallEnd>());

      final finished = events.last as RunFinished;
      expect(finished.json['outcome'], containsPair('type', 'interrupt'));
    });

    test('reads RUN_ERROR, with and without RUN_STARTED', () {
      final unknownInterrupt = _decode('G3');
      expect(unknownInterrupt, hasLength(1));
      final error = unknownInterrupt.single as RunError;
      expect(error.code, 'UNKNOWN_INTERRUPT');
      expect(error.message, contains('unknown interrupt'));

      final execution = _decode('M1');
      expect(execution.first, isA<RunStarted>());
      expect((execution.last as RunError).code, 'EXECUTION_ERROR');
    });

    test('reads the text of a streamed message', () {
      final events = _decode('slow');
      final start = events.whereType<TextStart>().single;
      final text = events
          .whereType<TextContent>()
          .where((event) => event.messageId == start.messageId)
          .map((event) => event.delta)
          .join();

      expect(text, "You said: '#slow #chat hello'. Draft I see: null");
      expect(events.whereType<TextEnd>().single.messageId, start.messageId);
    });
  });
}

List<WireEvent> _decode(String name) => [
  for (final json in AgUiAdkTranscripts.frames(name)) WireEvent.fromJson(json),
];
