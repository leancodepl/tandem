import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';

void main() {
  group('WireMessage.fromJson', () {
    test('reads a user message', () {
      final message = WireMessage.fromJson(const {
        'id': 'u1',
        'role': 'user',
        'content': 'Order 40 HDMI cables',
      });

      expect(
        message,
        isA<WireUserMessage>()
            .having((m) => m.id, 'id', 'u1')
            .having((m) => m.content, 'content', 'Order 40 HDMI cables'),
      );
    });

    test('reads an assistant message with tool calls', () {
      final message = WireMessage.fromJson(const {
        'id': 'a1',
        'role': 'assistant',
        'content': 'Searching',
        'toolCalls': [
          {
            'id': 'c1',
            'type': 'function',
            'function': {
              'name': 'search_catalog',
              'arguments': '{"query":"HDMI"}',
            },
          },
        ],
      });

      expect(message, isA<WireAssistantMessage>());
      final assistant = message! as WireAssistantMessage;
      expect(assistant.id, 'a1');
      expect(assistant.content, 'Searching');
      expect(assistant.toolCalls, hasLength(1));
      expect(assistant.toolCalls.single.id, 'c1');
      expect(assistant.toolCalls.single.name, 'search_catalog');
      expect(assistant.toolCalls.single.arguments, '{"query":"HDMI"}');
    });

    test('reads tool calls with snake_case keys and any arguments', () {
      final assistant =
          WireMessage.fromJson(const {
                'id': 'a1',
                'role': 'assistant',
                'tool_calls': [
                  {
                    'id': 'c1',
                    'function': {
                      'name': 'place_order',
                      'arguments': {'confirm': true},
                    },
                  },
                  {
                    'id': 'c2',
                    'function': {'name': 'clear'},
                  },
                  {'id': 'c3'},
                  {
                    'function': {'name': 'no_id'},
                  },
                  'not a call',
                ],
              })
              as WireAssistantMessage?;

      expect(assistant!.content, isNull);
      expect(assistant.toolCalls.map((call) => call.id), ['c1', 'c2']);
      expect(assistant.toolCalls[0].arguments, '{"confirm":true}');
      expect(assistant.toolCalls[1].arguments, '{}');
    });

    test('reads a tool message, with snake_case keys too', () {
      for (final key in ['toolCallId', 'tool_call_id']) {
        final message = WireMessage.fromJson({
          'id': 't1',
          'role': 'tool',
          key: 'c1',
          'content': '{"status":"ok"}',
        });

        expect(
          message,
          isA<WireToolMessage>()
              .having((m) => m.id, 'id', 't1')
              .having((m) => m.toolCallId, 'toolCallId', 'c1')
              .having((m) => m.content, 'content', '{"status":"ok"}'),
        );
      }
    });

    test('tolerates content given as parts', () {
      const parts = [
        {'type': 'text', 'text': '{"status":'},
        {'type': 'image', 'url': 'https://example.com/a.png'},
        {'type': 'text', 'text': '"ok"}'},
        'not a part',
      ];

      final tool = WireMessage.fromJson(const {
        'id': 't1',
        'role': 'tool',
        'toolCallId': 'c1',
        'content': parts,
      });
      final user = WireMessage.fromJson(const {
        'id': 'u1',
        'role': 'user',
        'content': parts,
      });

      expect((tool! as WireToolMessage).content, '{"status":"ok"}');
      expect((user! as WireUserMessage).content, '{"status":"ok"}');
    });

    test('gives empty content when a user or tool message has none', () {
      final user = WireMessage.fromJson(const {'id': 'u1', 'role': 'user'});
      final tool = WireMessage.fromJson(const {
        'id': 't1',
        'role': 'tool',
        'toolCallId': 'c1',
        'content': 7,
      });

      expect((user! as WireUserMessage).content, '');
      expect((tool! as WireToolMessage).content, '');
    });

    test('returns null for roles Tandem drops', () {
      for (final role in [
        'developer',
        'system',
        'activity',
        'reasoning',
        'narrator',
      ]) {
        expect(
          WireMessage.fromJson({'id': 'x', 'role': role, 'content': 'Hi'}),
          isNull,
          reason: role,
        );
      }
    });

    test('returns null for a message it cannot use', () {
      expect(
        WireMessage.fromJson(const {'role': 'user', 'content': 'Hi'}),
        isNull,
      );
      expect(WireMessage.fromJson(const {'id': 7, 'role': 'user'}), isNull);
      expect(WireMessage.fromJson(const {'id': 'x', 'content': 'Hi'}), isNull);
      expect(
        WireMessage.fromJson(const {
          'id': 't',
          'role': 'tool',
          'content': 'ok',
        }),
        isNull,
      );
    });
  });

  group('WireMessage.toJson', () {
    test('writes the AG-UI shape with camelCase keys', () {
      const call = WireToolCall(
        id: 'c1',
        name: 'search_catalog',
        arguments: '{"query":"HDMI"}',
      );

      expect(const WireUserMessage('u1', 'Hi').toJson(), {
        'id': 'u1',
        'role': 'user',
        'content': 'Hi',
      });
      expect(
        const WireAssistantMessage(
          'a1',
          content: 'Searching',
          toolCalls: [call],
        ).toJson(),
        {
          'id': 'a1',
          'role': 'assistant',
          'content': 'Searching',
          'toolCalls': [
            {
              'id': 'c1',
              'type': 'function',
              'function': {
                'name': 'search_catalog',
                'arguments': '{"query":"HDMI"}',
              },
            },
          ],
        },
      );
      expect(
        const WireToolMessage(
          'tool-1',
          toolCallId: 'c1',
          content: '{"status":"ok"}',
        ).toJson(),
        {
          'id': 'tool-1',
          'role': 'tool',
          'content': '{"status":"ok"}',
          'toolCallId': 'c1',
        },
      );
    });

    test('leaves out the content and tool calls an assistant has not', () {
      expect(const WireAssistantMessage('a1').toJson(), {
        'id': 'a1',
        'role': 'assistant',
      });
      expect(
        const WireAssistantMessage(
          'asst-c1',
          toolCalls: [WireToolCall(id: 'c1', name: 'clear', arguments: '{}')],
        ).toJson().keys,
        ['id', 'role', 'toolCalls'],
      );
    });

    test('round-trips through fromJson', () {
      const messages = <WireMessage>[
        WireUserMessage('u1', 'Hi'),
        WireAssistantMessage(
          'a1',
          content: 'Done',
          toolCalls: [WireToolCall(id: 'c1', name: 'x', arguments: '{"a":1}')],
        ),
        WireToolMessage('t1', toolCallId: 'c1', content: 'ok'),
      ];

      for (final message in messages) {
        expect(
          WireMessage.fromJson(message.toJson())!.toJson(),
          message.toJson(),
        );
      }
    });
  });
}
