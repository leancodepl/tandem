import 'package:example/recipes/fill_from_email/contact_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/testing.dart';

void main() {
  testWidgets('the button sends the e-mail and the agent fills the form', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [
        AgentStep.callTool('set_name', {'name': 'Marta Nowak'}),
        AgentStep.callTool('set_company', {'company': 'Acme Office Supply'}),
      ],
      (_) => const [AgentStep.say('There is no e-mail address in it.')],
    ]);
    await tester.pumpWidget(
      MaterialApp(home: ContactScreen(connection: agent)),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Pasted e-mail'),
      'Thanks, Marta Nowak, Acme Office Supply',
    );
    await tester.tap(find.text('Fill from e-mail'));
    await tester.pumpAndSettle();

    expect(
      agent.requests.first['messages'].toString(),
      contains('Thanks, Marta Nowak, Acme Office Supply'),
    );
    expect(find.widgetWithText(TextField, 'Marta Nowak'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Acme Office Supply'),
      findsOneWidget,
    );
    expect(find.text('There is no e-mail address in it.'), findsOneWidget);
  });
}
