import 'package:example/quick_start.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

const viewToolName = 'tandem_show_view';

void main() {
  testWidgets('a coding agent adds an item to the list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));

    final answer = await TandemBridge.call('add', arguments: {'item': 'milk'});
    await tester.pump();

    expect(answer['status'], ToolStatus.returned);
    expect(find.text('milk'), findsOneWidget);
  });

  testWidgets('a coding agent does not clear the list when the user cancels', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));
    await TandemBridge.call('add', arguments: {'item': 'milk'});

    final answer = await callClearAndTap(tester, 'Cancel');

    expect(answer, containsPair('status', ToolStatus.rejectedByUser));
    expect(find.text('milk'), findsOneWidget);
  });

  testWidgets('a coding agent clears the list once the user approves', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));
    await TandemBridge.call('add', arguments: {'item': 'milk'});

    final answer = await callClearAndTap(tester, 'Clear');

    expect(answer, containsPair('status', ToolStatus.returned));
    expect(find.text('milk'), findsNothing);
  });

  testWidgets('a coding agent suggests an item and the user adds it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShoppingScreen()));
    final viewTool = containsPair('name', viewToolName);
    expect(TandemBridge.describe(), {
      'screens': [containsPair('tools', contains(viewTool))],
    });

    final answer = await TandemBridge.call(
      viewToolName,
      arguments: {'components': const ShoppingCatalog().example},
    );
    await tester.pump();
    expect(answer, containsPair('status', ToolStatus.shown));
    expect(find.widgetWithText(Suggestion, 'milk'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'milk'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Suggestion, 'milk'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'milk'), findsNWidgets(2));
  });
}

Future<Map<String, Object?>> callClearAndTap(
  WidgetTester tester,
  String button,
) async {
  final answer = TandemBridge.call('clear');
  await tester.pumpAndSettle();
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  return await answer;
}
