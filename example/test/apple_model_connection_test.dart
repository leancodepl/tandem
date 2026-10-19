import 'dart:async';
import 'dart:convert';

import 'package:example/agent_chat.dart';
import 'package:example/apple_foundation_models/apple_model_connection.dart';
import 'package:example/shopping_list/shopping_list.dart'
    show ShoppingListScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('tandem/apple_foundation_models');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test(
    'a missing native host reports unavailable without a fake model',
    () async {
      final availability = await AppleModelConnection().availability();

      expect(availability.available, isFalse);
      expect(availability.reason, contains('iOS or macOS native host'));
    },
  );

  test(
    'native errors stay actionable and a new run clears the reason',
    () async {
      var fails = true;
      _handle((call) async {
        if (fails) {
          throw PlatformException(
            code: 'GENERATION_FAILED',
            message: 'The conversation exceeds the model context window.',
          );
        }
        return {'kind': 'text', 'text': 'Ready.'};
      });
      final connection = AppleModelConnection();

      final events = await connection.run(_input()).toList();

      expect(events.last['code'], 'GENERATION_FAILED');
      expect(connection.error.value, contains('context window'));

      fails = false;
      await connection.run(_input()).toList();

      expect(connection.error.value, isNull);
    },
  );

  test('invalid native calls fail before publishing a tool event', () async {
    for (final response in [
      {'kind': 'tool', 'name': 'unlisted', 'arguments': '{}'},
      {'kind': 'tool', 'name': 'add', 'arguments': '["Milk"]'},
    ]) {
      _handle((call) async => response);

      final events = await AppleModelConnection().run(_input()).toList();

      expect(events.map((event) => event['type']), [
        'RUN_STARTED',
        'RUN_ERROR',
      ]);
      expect(events.last['code'], 'INVALID_RESPONSE');
    }
  });

  test('disposing a run cancels native generation while it waits', () async {
    final response = Completer<Object?>();
    final started = Completer<void>();
    final cancelled = Completer<void>();
    _handle((call) async {
      switch (call.method) {
        case 'run':
          started.complete();
          return await response.future;
        case 'cancel':
          expect(call.arguments, {'runId': 'run-1'});
          cancelled.complete();
          response.completeError(
            PlatformException(code: 'CANCELLED', message: 'Cancelled.'),
          );
          return null;
      }
      return null;
    });
    final subscription = AppleModelConnection().run(_input()).listen((_) {});
    await started.future;

    await subscription.cancel();

    expect(cancelled.isCompleted, isTrue);
  });

  test('a runaway sequence stops before another native generation', () async {
    var calls = 0;
    _handle((call) async {
      calls++;
      return {'kind': 'text', 'text': 'Unexpected.'};
    });
    final input = _input();
    input['messages'] = [
      {'role': 'user', 'content': 'Add items'},
      for (var index = 0; index < 12; index++)
        {'role': 'tool', 'content': 'null'},
    ];

    final events = await AppleModelConnection().run(input).toList();

    expect(events.last['type'], 'RUN_ERROR');
    expect(events.last['code'], 'TOOL_LIMIT');
    expect(calls, 0);
  });

  testWidgets('local calls update state and clear only after approval', (
    tester,
  ) async {
    final requests = <Map<Object?, Object?>>[];
    _respondWith(requests, [
      {'kind': 'tool', 'name': 'add', 'arguments': '{"item":"Milk"}'},
      {'kind': 'text', 'text': 'Added milk.'},
      {'kind': 'tool', 'name': 'clear', 'arguments': '{}'},
      {'kind': 'text', 'text': 'Cleared the list.'},
    ]);
    await _open(tester);

    await _send(tester, 'Add milk');

    expect(find.byTooltip('Remove Milk'), findsOneWidget);
    expect(requests, hasLength(2));
    expect(requests[1]['messages'], contains(containsPair('role', 'tool')));
    expect(jsonEncode(requests[1]['context']), contains('Milk'));
    expect(_toolNames(requests[1]), contains('clear'));

    await _send(tester, 'Empty the list');

    expect(find.byTooltip('Remove Milk'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(requests, hasLength(3));

    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove Milk'), findsNothing);
    expect(find.text('Cleared the list.'), findsOneWidget);
    expect(requests, hasLength(4));
    expect(jsonEncode(requests.last['messages']), contains('"content":"null"'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual edits invalidate approval and refresh native context', (
    tester,
  ) async {
    final requests = <Map<Object?, Object?>>[];
    _respondWith(requests, [
      {'kind': 'tool', 'name': 'add', 'arguments': '{"item":"Milk"}'},
      {'kind': 'text', 'text': 'Added milk.'},
      {'kind': 'tool', 'name': 'clear', 'arguments': '{}'},
      {'kind': 'text', 'text': 'The list is already empty.'},
    ]);
    await _open(tester);
    await _send(tester, 'Add milk');
    await _send(tester, 'Empty the list');

    await tester.tap(find.byTooltip('Remove Milk'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(
      find.text('What the agent saw changed. Ask it again.'),
      findsOneWidget,
    );
    expect(requests, hasLength(3));

    await _send(tester, 'Check again');

    expect(jsonEncode(requests.last['messages']), contains('invalidated'));
    expect(jsonEncode(requests.last['context']), isNot(contains('Milk')));
    expect(_toolNames(requests.last), isNot(contains('clear')));
    expect(tester.takeException(), isNull);
  });
}

void _handle(Future<Object?> Function(MethodCall call) handler) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, handler);

void _respondWith(
  List<Map<Object?, Object?>> requests,
  List<Map<String, Object?>> responses,
) => _handle((call) async {
  expect(call.method, 'run');
  requests.add(call.arguments as Map<Object?, Object?>);
  return responses[requests.length - 1];
});

Future<void> _open(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(home: ShoppingListScreen(connection: AppleModelConnection())),
);

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AgentChat),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.tap(find.text('Send'));
  await tester.pumpAndSettle();
}

Map<String, Object?> _input() => {
  'threadId': 'thread-1',
  'runId': 'run-1',
  'messages': <Object?>[],
  'context': <Object?>[],
  'tools': [
    {
      'name': 'add',
      'description': 'Add an item',
      'parameters': {
        'type': 'object',
        'properties': {
          'item': {'type': 'string'},
        },
        'required': ['item'],
      },
    },
  ],
};

List<String> _toolNames(Map<Object?, Object?> request) => [
  if (request['tools'] case final List<Object?> tools)
    for (final tool in tools)
      if (tool case {'name': final String name}) name,
];
