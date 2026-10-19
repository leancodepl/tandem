import 'package:example/recipes/riverpod/cart_notifier.dart';
import 'package:example/recipes/riverpod/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/testing.dart';

void main() {
  testWidgets('a change to the cart invalidates the checkout card', (
    tester,
  ) async {
    final agent = ScriptedAgent([
      (_) => const [AgentStep.callTool('checkout')],
    ]);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: CartScreen(connection: agent)),
      ),
    );
    ProviderScope.containerOf(tester.element(find.byType(CartScreen)))
        .read(cartProvider.notifier)
      ..add('milk')
      ..add('bread');
    await tester.enterText(
      find.widgetWithText(TextField, 'Message the agent'),
      'Check out',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove bread'));
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(
      find.text('What the agent saw changed. Ask it again.'),
      findsOneWidget,
    );
  });
}
