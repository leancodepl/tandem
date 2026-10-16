import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';

/// The smallest valid JSON of every event type Tandem models.
const _knownEvents = <String, Map<String, Object?>>{
  'RUN_STARTED': {'type': 'RUN_STARTED', 'threadId': 't', 'runId': 'r'},
  'RUN_FINISHED': {'type': 'RUN_FINISHED', 'threadId': 't', 'runId': 'r'},
  'RUN_ERROR': {'type': 'RUN_ERROR', 'message': 'Boom', 'code': 'X'},
  'TEXT_MESSAGE_START': {'type': 'TEXT_MESSAGE_START', 'messageId': 'm'},
  'TEXT_MESSAGE_CONTENT': {
    'type': 'TEXT_MESSAGE_CONTENT',
    'messageId': 'm',
    'delta': 'Hi',
  },
  'TEXT_MESSAGE_END': {'type': 'TEXT_MESSAGE_END', 'messageId': 'm'},
  'TEXT_MESSAGE_CHUNK': {
    'type': 'TEXT_MESSAGE_CHUNK',
    'messageId': 'm',
    'delta': 'Hi',
  },
  'TOOL_CALL_START': {
    'type': 'TOOL_CALL_START',
    'toolCallId': 'c',
    'toolCallName': 'search',
  },
  'TOOL_CALL_ARGS': {
    'type': 'TOOL_CALL_ARGS',
    'toolCallId': 'c',
    'delta': '{}',
  },
  'TOOL_CALL_END': {'type': 'TOOL_CALL_END', 'toolCallId': 'c'},
  'TOOL_CALL_CHUNK': {
    'type': 'TOOL_CALL_CHUNK',
    'toolCallId': 'c',
    'toolCallName': 'search',
    'delta': '{}',
  },
  'TOOL_CALL_RESULT': {
    'type': 'TOOL_CALL_RESULT',
    'messageId': 'm',
    'toolCallId': 'c',
    'content': 'ok',
  },
  'STATE_SNAPSHOT': {
    'type': 'STATE_SNAPSHOT',
    'snapshot': {'order': <String, Object?>{}},
  },
  'STATE_DELTA': {
    'type': 'STATE_DELTA',
    'delta': [
      {'op': 'remove', 'path': '/order'},
    ],
  },
  'MESSAGES_SNAPSHOT': {
    'type': 'MESSAGES_SNAPSHOT',
    'messages': [
      {'id': 'u', 'role': 'user', 'content': 'Hi'},
    ],
  },
};

void main() {
  group('WireEvent.fromJson', () {
    test('gives every known type its own class', () {
      final classes = {
        for (final MapEntry(:key, :value) in _knownEvents.entries)
          key: WireEvent.fromJson(value),
      };

      expect(classes['RUN_STARTED'], isA<RunStarted>());
      expect(classes['RUN_FINISHED'], isA<RunFinished>());
      expect(classes['RUN_ERROR'], isA<RunError>());
      expect(classes['TEXT_MESSAGE_START'], isA<TextStart>());
      expect(classes['TEXT_MESSAGE_CONTENT'], isA<TextContent>());
      expect(classes['TEXT_MESSAGE_END'], isA<TextEnd>());
      expect(classes['TEXT_MESSAGE_CHUNK'], isA<TextChunk>());
      expect(classes['TOOL_CALL_START'], isA<ToolCallStart>());
      expect(classes['TOOL_CALL_ARGS'], isA<ToolCallArgs>());
      expect(classes['TOOL_CALL_END'], isA<ToolCallEnd>());
      expect(classes['TOOL_CALL_CHUNK'], isA<ToolCallChunk>());
      expect(classes['TOOL_CALL_RESULT'], isA<ToolCallResult>());
      expect(classes['STATE_SNAPSHOT'], isA<StateSnapshot>());
      expect(classes['STATE_DELTA'], isA<StateDelta>());
      expect(classes['MESSAGES_SNAPSHOT'], isA<MessagesSnapshot>());
      for (final MapEntry(:key, :value) in classes.entries) {
        expect(value.type, key);
        expect(value.json, same(_knownEvents[key]));
      }
    });

    test('reads the fields of each event', () {
      final error = WireEvent.fromJson(_knownEvents['RUN_ERROR']!) as RunError;
      expect(error.message, 'Boom');
      expect(error.code, 'X');

      final content =
          WireEvent.fromJson(_knownEvents['TEXT_MESSAGE_CONTENT']!)
              as TextContent;
      expect(content.messageId, 'm');
      expect(content.delta, 'Hi');

      final chunk =
          WireEvent.fromJson(_knownEvents['TOOL_CALL_CHUNK']!) as ToolCallChunk;
      expect(chunk.toolCallId, 'c');
      expect(chunk.toolCallName, 'search');
      expect(chunk.parentMessageId, isNull);
      expect(chunk.delta, '{}');

      final snapshot =
          WireEvent.fromJson(_knownEvents['STATE_SNAPSHOT']!) as StateSnapshot;
      expect(snapshot.snapshot, {'order': <String, Object?>{}});

      final delta =
          WireEvent.fromJson(_knownEvents['STATE_DELTA']!) as StateDelta;
      expect(delta.operations, [
        {'op': 'remove', 'path': '/order'},
      ]);

      final messages =
          WireEvent.fromJson(_knownEvents['MESSAGES_SNAPSHOT']!)
              as MessagesSnapshot;
      expect(
        messages.messages.single,
        isA<WireUserMessage>().having((m) => m.content, 'content', 'Hi'),
      );
    });

    test('reads snake_case keys', () {
      final start =
          WireEvent.fromJson(const {
                'type': 'TOOL_CALL_START',
                'tool_call_id': 'c1',
                'tool_call_name': 'search_catalog',
                'parent_message_id': 'm1',
              })
              as ToolCallStart;
      expect(start.toolCallId, 'c1');
      expect(start.toolCallName, 'search_catalog');
      expect(start.parentMessageId, 'm1');

      final started =
          WireEvent.fromJson(const {
                'type': 'RUN_STARTED',
                'thread_id': 't1',
                'run_id': 'r1',
              })
              as RunStarted;
      expect(started.threadId, 't1');
      expect(started.runId, 'r1');

      final result =
          WireEvent.fromJson(const {
                'type': 'TOOL_CALL_RESULT',
                'message_id': 'm2',
                'tool_call_id': 'c1',
                'content': 'done',
              })
              as ToolCallResult;
      expect(result.messageId, 'm2');
      expect(result.toolCallId, 'c1');

      final chunk =
          WireEvent.fromJson(const {
                'type': 'TEXT_MESSAGE_CHUNK',
                'message_id': 'm3',
                'delta': 'Hi',
              })
              as TextChunk;
      expect(chunk.messageId, 'm3');
    });

    test('prefers the camelCase key when both are present', () {
      final end =
          WireEvent.fromJson(const {
                'type': 'TOOL_CALL_END',
                'toolCallId': 'camel',
                'tool_call_id': 'snake',
              })
              as ToolCallEnd;

      expect(end.toolCallId, 'camel');
    });

    test('keeps fields Tandem does not model in json', () {
      const json = {
        'type': 'RUN_FINISHED',
        'threadId': 't',
        'runId': 'r',
        'outcome': {'type': 'success', 'pendingToolCallIds': <String>[]},
        'usage': [
          {'inputTokens': 10},
        ],
      };

      final event = WireEvent.fromJson(json);

      expect(event, isA<RunFinished>());
      expect(event.json, same(json));
    });

    test('accepts optional fields that are missing', () {
      expect(
        WireEvent.fromJson(const {'type': 'RUN_ERROR'}),
        isA<RunError>()
            .having((e) => e.message, 'message', '')
            .having((e) => e.code, 'code', isNull),
      );
      expect(
        WireEvent.fromJson(const {
          'type': 'TEXT_MESSAGE_CONTENT',
          'messageId': 'm',
        }),
        isA<TextContent>().having((e) => e.delta, 'delta', ''),
      );
      expect(
        WireEvent.fromJson(const {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c'}),
        isA<ToolCallArgs>().having((e) => e.delta, 'delta', ''),
      );
      expect(
        WireEvent.fromJson(const {'type': 'TEXT_MESSAGE_CHUNK'}),
        isA<TextChunk>()
            .having((e) => e.messageId, 'messageId', isNull)
            .having((e) => e.delta, 'delta', isNull),
      );
      expect(
        WireEvent.fromJson(const {'type': 'TOOL_CALL_CHUNK', 'delta': '}'}),
        isA<ToolCallChunk>()
            .having((e) => e.toolCallId, 'toolCallId', isNull)
            .having((e) => e.toolCallName, 'toolCallName', isNull),
      );
      expect(
        WireEvent.fromJson(const {'type': 'RUN_FINISHED'}),
        isA<RunFinished>(),
      );
    });

    test('encodes a TOOL_CALL_RESULT content that is not a string', () {
      final result =
          WireEvent.fromJson(const {
                'type': 'TOOL_CALL_RESULT',
                'messageId': 'm',
                'toolCallId': 'c',
                'content': {'status': 'ok', 'count': 2},
              })
              as ToolCallResult;

      expect(result.content, '{"status":"ok","count":2}');
    });

    test('drops messages of roles Tandem does not keep from a snapshot', () {
      final snapshot =
          WireEvent.fromJson(const {
                'type': 'MESSAGES_SNAPSHOT',
                'messages': [
                  {'id': 's', 'role': 'system', 'content': 'Be nice'},
                  {'id': 'u', 'role': 'user', 'content': 'Hi'},
                  {'id': 'r', 'role': 'reasoning', 'content': 'Hmm'},
                  'not a message',
                  {
                    'id': 't',
                    'role': 'tool',
                    'tool_call_id': 'c',
                    'content': [
                      {'type': 'text', 'text': '{"status":"ok"}'},
                    ],
                  },
                ],
              })
              as MessagesSnapshot;

      expect(snapshot.messages.map((m) => m.id), ['u', 't']);
      expect(
        snapshot.messages.last,
        isA<WireToolMessage>()
            .having((m) => m.toolCallId, 'toolCallId', 'c')
            .having((m) => m.content, 'content', '{"status":"ok"}'),
      );
    });
  });

  group('UnknownEvent', () {
    test('holds an unknown type, without a problem', () {
      const json = {'type': 'SUBAGENT_STARTED', 'subagentRunId': 'sa-1'};

      final event = WireEvent.fromJson(json);

      expect(
        event,
        isA<UnknownEvent>().having((e) => e.problem, 'problem', isNull),
      );
      expect(event.type, 'SUBAGENT_STARTED');
      expect(event.json, same(json));
    });

    test('holds JSON without a type, with a problem', () {
      for (final json in [
        <String, Object?>{},
        {'type': 42},
        {'type': null, 'messageId': 'm'},
      ]) {
        final event = WireEvent.fromJson(json);

        expect(
          event,
          isA<UnknownEvent>().having((e) => e.problem, 'problem', isNotNull),
          reason: '$json',
        );
        expect(event.type, '');
        expect(event.json, same(json));
      }
    });

    test('holds a known type without a required field, with a problem', () {
      const json = {'type': 'TOOL_CALL_START', 'toolCallId': 'c'};

      final event = WireEvent.fromJson(json);

      expect(
        event,
        isA<UnknownEvent>().having(
          (e) => e.problem,
          'problem',
          allOf(contains('TOOL_CALL_START'), contains('toolCallName')),
        ),
      );
      expect(event.type, 'TOOL_CALL_START');
      expect(event.json, same(json));
    });

    test('holds a known type whose field has the wrong type', () {
      final malformed = <Map<String, Object?>>[
        {'type': 'RUN_STARTED', 'threadId': 7, 'runId': 'r'},
        {'type': 'TEXT_MESSAGE_START', 'messageId': null},
        {'type': 'TOOL_CALL_RESULT', 'messageId': 'm', 'toolCallId': 'c'},
        {'type': 'STATE_SNAPSHOT', 'snapshot': <Object?>[]},
        {'type': 'STATE_SNAPSHOT'},
        {
          'type': 'STATE_DELTA',
          'delta': [
            {'op': 'remove', 'path': '/a'},
            'remove /b',
          ],
        },
        {'type': 'STATE_DELTA', 'delta': <String, Object?>{}},
        {'type': 'MESSAGES_SNAPSHOT', 'messages': 'none'},
      ];

      for (final json in malformed) {
        expect(
          WireEvent.fromJson(json),
          isA<UnknownEvent>().having((e) => e.problem, 'problem', isNotNull),
          reason: '$json',
        );
      }
    });

    test('never throws, whatever the fields hold', () {
      const garbage = <Object?>[
        null,
        42,
        1.5,
        true,
        '',
        <Object?>[],
        <String, Object?>{},
        [null, 1, 'x'],
        {'nested': <Object?>[]},
      ];

      for (final sample in _knownEvents.values) {
        for (final key in sample.keys.where((key) => key != 'type')) {
          for (final value in garbage) {
            final json = {...sample, key: value};
            expect(
              () => WireEvent.fromJson(json),
              returnsNormally,
              reason: '$json',
            );
          }
        }
      }
    });
  });
}
