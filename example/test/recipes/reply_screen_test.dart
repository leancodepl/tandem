import 'package:example/recipes/approval_dialog/reply_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/testing.dart';

void main() {
  testWidgets('the reply goes out only after Send in the dialog', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('set_reply', {'text': 'It ships on Monday.'}),
      ],
      (_) => const [AgentStep.callTool('send')],
      (_) => const [AgentStep.say('Sent.')],
    ]);
    await tester.pumpWidget(MaterialApp(home: ReplyScreen(connection: agent)));

    await tester.tap(find.text('Answer with the agent'));
    await tester.pumpAndSettle();

    expect(find.text('Send this reply?'), findsOneWidget);
    expect(find.text('Sent'), findsNothing);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Send this reply?'), findsNothing);
    expect(find.text('Sent'), findsOneWidget);
    expect(agent.requests, hasLength(3));
  });
}
