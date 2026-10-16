import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/protocol.dart';

void main() {
  group('RunInput.toJson', () {
    test('is the AG-UI request body, with camelCase keys', () {
      const input = RunInput(
        threadId: 'thread-1',
        runId: 'run-2',
        messages: [
          WireUserMessage('u1', 'Order 40 HDMI cables'),
          WireAssistantMessage(
            'asst-c1',
            toolCalls: [
              WireToolCall(
                id: 'c1',
                name: 'search_catalog',
                arguments: '{"query":"HDMI"}',
              ),
            ],
          ),
          WireToolMessage(
            'tool-1',
            toolCallId: 'c1',
            content: '{"status":"ok","result":[]}',
          ),
        ],
        tools: [
          WireTool(
            name: 'search_catalog',
            description: 'Find products.',
            parameters: {
              'type': 'object',
              'properties': {
                'query': {'type': 'string'},
              },
              'required': ['query'],
            },
          ),
        ],
        state: {
          'order': {
            'lines': [
              {'sku': 'HDMI-2M', 'quantity': 40},
            ],
          },
        },
        context: [WireContext(description: 'locale', value: 'pl-PL')],
        forwardedProps: {'tenant': 'acme'},
      );

      expect(input.toJson(), {
        'threadId': 'thread-1',
        'runId': 'run-2',
        'state': {
          'order': {
            'lines': [
              {'sku': 'HDMI-2M', 'quantity': 40},
            ],
          },
        },
        'messages': [
          {'id': 'u1', 'role': 'user', 'content': 'Order 40 HDMI cables'},
          {
            'id': 'asst-c1',
            'role': 'assistant',
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
          {
            'id': 'tool-1',
            'role': 'tool',
            'content': '{"status":"ok","result":[]}',
            'toolCallId': 'c1',
          },
        ],
        'tools': [
          {
            'name': 'search_catalog',
            'description': 'Find products.',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {'type': 'string'},
              },
              'required': ['query'],
            },
          },
        ],
        'context': [
          {'description': 'locale', 'value': 'pl-PL'},
        ],
        'forwardedProps': {'tenant': 'acme'},
      });
    });

    test(
      'always contains every key, because ag-ui-adk fails without tools',
      () {
        const input = RunInput(
          threadId: 't',
          runId: 'r',
          messages: [],
          tools: [],
          state: {},
        );

        expect(
          jsonEncode(input.toJson()),
          '{"threadId":"t","runId":"r","state":{},"messages":[],"tools":[],'
          '"context":[],"forwardedProps":{}}',
        );
      },
    );
  });
}
