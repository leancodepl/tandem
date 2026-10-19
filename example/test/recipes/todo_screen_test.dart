import 'package:example/recipes/change_notifier/todo_list.dart';
import 'package:example/recipes/change_notifier/todo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tandem/testing.dart';

void main() {
  testWidgets('a new to-do invalidates the card that clears the list', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('clear')],
    ]);
    await tester.pumpWidget(MaterialApp(home: TodoScreen(connection: agent)));
    Provider.of<TodoList>(
      tester.element(find.text('Send')),
      listen: false,
    ).add('Call the bank');
    await tester.enterText(
      find.widgetWithText(TextField, 'Message the agent'),
      'Clear my list',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a task'),
      'Water the plants',
    );
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(
      find.text('What the agent saw changed. Ask it again.'),
      findsOneWidget,
    );
  });
}
