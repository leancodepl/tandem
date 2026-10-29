import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/session/run_method.dart';
import 'package:tandem/src/session/tool_answer.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('an ArgumentError answers failed like any other error, and only the '
      'report gets it', () async {
    const secret = 'internal-account-token-123';
    for (final error in [
      StateError(secret),
      ArgumentError.value(secret, 'account'),
    ]) {
      final reported = <Object>[];
      final outcome = await runMethod(
        AgentListing.of(_Surface(() => throw error)),
        'execute',
        const WrittenArguments({}),
        caller: .inAppAgent,
        approved: false,
        report: (error, _) => reported.add(error),
      );

      expect(outcome.answer, ToolAnswer.failed);
      expect(outcome.returned, isNull);
      expect(reported.single, same(error));
    }
  });

  test('a result that cannot be encoded answers result_unavailable, and the '
      'call still returned', () async {
    final reported = <Object>[];
    final outcome = await runMethod(
      AgentListing.of(_Surface(() => double.nan)),
      'execute',
      const WrittenArguments({}),
      caller: .inAppAgent,
      approved: false,
      report: (error, _) => reported.add(error),
    );

    expect(outcome.answer.json, {
      'status': 'result_unavailable',
      'reason': isNotEmpty,
    });
    expect(outcome.returned?.tool, 'execute');
    expect(outcome.returned?.result, isNaN);
    expect(reported.single, isA<JsonUnsupportedObjectError>());
  });
}

final class _Surface(final FutureOr<Object?> Function() operation)
    implements AgentSurface {
  FutureOr<Object?> execute() => operation();

  @override
  List<AgentCapability> get agentCapabilities => [.calls(execute)];

  @override
  Stream<Object?> get changes => const Stream.empty();

  @override
  AgentSchema get agentSchema => AgentSchema(
    sees: [],
    calls: [
      AgentTool(
        execute,
        name: 'execute',
        description: 'Executes an operation.',
        parameters: const [],
        invoke: (_) => execute(),
      ),
    ],
  );
}
