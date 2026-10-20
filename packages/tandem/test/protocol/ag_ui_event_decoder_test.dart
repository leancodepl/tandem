import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/ag_ui_event_decoder.dart';
import 'package:tandem/src/protocol/events.dart';

void main() {
  test('ignores unknown events and invalid required fields', () {
    final events = <Map<String, Object?>>[
      {},
      {'type': 'FUTURE_EVENT'},
      {'type': 42},
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 'm1'},
      {'type': 'TEXT_MESSAGE_CONTENT', 'messageId': 42, 'delta': 'Hello'},
      {'type': 'TOOL_CALL_START', 'toolCallId': 'c1'},
      {'type': 'TOOL_CALL_START', 'toolCallId': false, 'toolCallName': 'add'},
      {'type': 'TOOL_CALL_ARGS', 'delta': '{}'},
      {'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': []},
    ];

    for (final event in events) {
      expect(decodeAgUiEvent(event), isA<IgnoredEvent>(), reason: '$event');
    }
  });

  test('reads the outcome of RUN_FINISHED as AG-UI 1.0 does', () {
    final cases = <(Map<String, Object?>, RunOutcome)>[
      ({}, .success),
      ({'outcome': null}, .success),
      (
        {
          'outcome': {'type': 'success'},
        },
        .success,
      ),
      (
        {
          'outcome': {'type': 'unknown'},
        },
        .success,
      ),
      (
        {
          'outcome': {'type': 'cancelled'},
        },
        .cancelled,
      ),
      (
        {
          'outcome': {'type': 'interrupt', 'interrupts': <Object?>[]},
        },
        .unsupported,
      ),
      ({'outcome': 'success'}, .unsupported),
      ({'outcome': <String, Object?>{}}, .unsupported),
      (
        {
          'outcome': {'type': 1},
        },
        .unsupported,
      ),
    ];

    for (final (fields, outcome) in cases) {
      expect(
        decodeAgUiEvent({'type': 'RUN_FINISHED', ...fields}),
        isA<RunFinished>().having((event) => event.outcome, 'outcome', outcome),
        reason: '$fields',
      );
    }
  });
}
