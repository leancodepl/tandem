import 'package:example/desk/data/emails.dart';
import 'package:example/gallery/demo.dart';
import 'package:example/gallery/demo_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every screen plays its scenario on a phone', (tester) async {
    await _pumpPhone(tester);

    for (final (demo, prompt, outcome) in const [
      (
        Demo.orderDesk,
        orderEmail,
        'The order is ready. Change quantities on the screen, '
            'then ask me to place the order.',
      ),
      (
        Demo.shoppingList,
        'Add milk and bread, then empty the list.',
        'Approve',
      ),
      (
        Demo.contact,
        'Fill from e-mail',
        'Contact filled. You can edit the fields.',
      ),
      (Demo.reply, 'Answer with the agent', 'Send this reply?'),
      (
        Demo.cart,
        'Add a keyboard and a USB-C cable, then check out.',
        'Approve',
      ),
      (Demo.todos, 'Add two release tasks, then clear the list.', 'Approve'),
    ]) {
      await _open(tester, demo);
      await tester.tap(find.text(prompt));
      await tester.pumpAndSettle();

      expect(find.text(outcome), findsOneWidget, reason: demo.title);
      if (demo == Demo.reply) {
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('reset starts a screen over', (tester) async {
    const prompt = 'Add milk and bread, then empty the list.';
    await _pumpPhone(tester);
    await _open(tester, Demo.shoppingList);
    await tester.tap(find.text(prompt));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset example'));
    await tester.pumpAndSettle();

    expect(find.text('Your shopping list is empty.'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, prompt), findsOneWidget);
  });

  testWidgets(
    'the order desk takes a backend URL, checks it and switches back',
    (tester) async {
      await _pumpPhone(tester);
      await _open(tester, Demo.orderDesk);
      await tester.tap(find.text('Use backend'));
      await tester.pumpAndSettle();
      final url = find.widgetWithText(TextField, 'Agent URL');
      expect(
        tester.widget<TextField>(url).controller?.text,
        'http://10.0.2.2:8000/agent',
      );

      await tester.enterText(url, 'not a URL');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an HTTP or HTTPS URL.'), findsOneWidget);

      await tester.enterText(url, 'http://192.168.1.20:8000/agent');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        find.text('Backend · http://192.168.1.20:8000/agent'),
        findsOneWidget,
      );

      await tester.tap(find.text('Use script'));
      await tester.pumpAndSettle();
      expect(find.text('Scripted · fixed responses'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(.android),
  );
}

Future<void> _pumpPhone(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const DemoApp());
}

Future<void> _open(WidgetTester tester, Demo demo) async {
  final title = find.text(demo.title);
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title);
  await tester.pumpAndSettle();
}
