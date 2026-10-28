import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/testing.dart';

void main() {
  test(
    'reads named context, offered tools and new notes without changing raw',
    () {
      final raw = <String, Object?>{
        'messages': [
          {'role': 'user', 'content': 'The app sent this'},
        ],
        'context': [
          {'description': 'order_history: Earlier orders.', 'value': '[1]'},
          {'description': 'order: The current order.', 'value': '{"lines":[]}'},
          {'description': 'order: Another entry.', 'value': '42'},
          {
            'description': 'app_notes: What happened outside the chat.',
            'value':
                '{"new":[{"note":"first"},{"pressed":"place_order",'
                '"result":"ORD-1"}],"earlier":[{"note":"old"}]}',
          },
        ],
        'tools': [
          {'name': 'place_order'},
        ],
      };
      final request = AgentRequest(raw);

      expect(request.raw, same(raw));
      expect(request.isUserMessage, isTrue);
      expect(request.context('order'), {'lines': <Object?>[]});
      expect(request.context('missing'), isNull);
      expect(request.offersTool('place_order'), isTrue);
      expect(request.offersTool('place'), isFalse);
      expect(request.newNotes, [
        {'note': 'first'},
        {'pressed': 'place_order', 'result': 'ORD-1'},
      ]);

      final empty = AgentRequest({});
      expect(empty.isUserMessage, isFalse);
      expect(empty.context('order'), isNull);
      expect(empty.offersTool('place_order'), isFalse);
      expect(empty.newNotes, isEmpty);
      expect(empty.latestToolResults, isEmpty);
    },
  );

  test('joins trailing answers by call id and preserves content without status '
      'classification', () {
    final messages = <Map<String, Object?>>[
      {
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'old',
            'function': {'name': 'old_call'},
          },
        ],
      },
      {'role': 'tool', 'toolCallId': 'old', 'content': 'null'},
      {'role': 'user', 'content': 'Continue'},
      {
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'second',
            'function': {'name': 'lookup'},
          },
          {
            'id': 'first',
            'function': {'name': 'place_order'},
          },
        ],
      },
      {
        'role': 'tool',
        'toolCallId': 'first',
        'content': '{"status":"rejected_by_user","orderId":"ORD-1"}',
      },
      {'role': 'tool', 'toolCallId': 'second', 'content': '[1,2]'},
      {'role': 'tool', 'toolCallId': 'unmatched', 'content': 'plain text'},
    ];
    final request = AgentRequest({'messages': messages});
    final results = request.latestToolResults;

    expect(results.map((result) => result.toolCallId), [
      'first',
      'second',
      'unmatched',
    ]);
    expect(results.map((result) => result.toolName), [
      'place_order',
      'lookup',
      null,
    ]);
    expect(
      results.first.content,
      '{"status":"rejected_by_user","orderId":"ORD-1"}',
    );
    expect(results.first.value, {
      'status': 'rejected_by_user',
      'orderId': 'ORD-1',
    });
    expect(results[1].value, [1, 2]);
    expect(results.last.content, 'plain text');
    expect(() => results.last.value, throwsFormatException);

    messages.add({'role': 'user', 'content': 'Next'});
    expect(request.latestToolResults, isEmpty);
  });

  test('reports malformed JSON only when the named context is read', () {
    final request = AgentRequest({
      'context': [
        {'description': 'broken: Invalid JSON.', 'value': '{'},
        {'description': 'empty: A null value.', 'value': 'null'},
      ],
    });

    expect(request.context('missing'), isNull);
    expect(request.context('empty'), isNull);
    expect(() => request.context('broken'), throwsFormatException);
  });
}
