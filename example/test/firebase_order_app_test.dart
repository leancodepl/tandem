import 'package:example/firebase_order_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:tandem_firebase_ai/tandem_firebase_ai.dart';

void main() {
  testWidgets('a new conversation recovers incompatible history and keeps '
      'the order draft', (tester) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('set_quantity', {'sku': 'VM-27Q', 'quantity': 15}),
      ],
      (_) => const [AgentStep.fail('Incompatible history.')],
      (_) => const [AgentStep.say('Ready.')],
    ]);
    await tester.pumpWidget(
      FirebaseOrderApp(connection: _FirebaseFailure(agent)),
    );
    await tester.tap(
      find.text('Add 15 VM-27Q monitors, then place the order.'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<AgentRunException>());
    expect(find.text('VM-27Q'), findsOneWidget);

    await tester.tap(find.text('New conversation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Continue with this draft');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Ready.'), findsOneWidget);
    expect(find.text('VM-27Q'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(
      agent.requests.last['threadId'],
      isNot(agent.requests.first['threadId']),
    );
    expect(agent.requests.last['messages'], [
      {
        'id': isA<String>(),
        'role': 'user',
        'content': 'Continue with this draft',
      },
    ]);
  });
}

final class _FirebaseFailure(final ScriptedAgent agent)
    implements AgentConnection {
  @override
  Stream<Map<String, Object?>> run(Map<String, Object?> input) => agent
      .run(input)
      .map(
        (event) => {
          ...event,
          if (event['type'] == 'RUN_ERROR')
            'code': FirebaseErrorCode.incompatibleHistory,
        },
      );
}
