import 'package:example/shopping_list/drawn_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the agent draws the list, a button removes an item, and one '
      'with approval empties it after Approve', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: DrawnListScreen(connection: drawnListAgent())),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Message the agent'),
      'Show my shopping list',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);

    await tester.tap(find.text('Empty the list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsNothing);
  });
}
