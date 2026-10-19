import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/protocol/events.dart';

void main() {
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
        AgentEvent.fromJson({'type': 'RUN_FINISHED', ...fields}),
        isA<RunFinished>().having((event) => event.outcome, 'outcome', outcome),
        reason: '$fields',
      );
    }
  });
}
