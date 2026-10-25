import 'package:example/desk/data/emails.dart';
import 'package:example/desk/ui/order_desk_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ready =
    'The order is ready. Change quantities on the screen, '
    'then ask me to place the order.';

void main() {
  testWidgets('the scripted agent fills the order on a phone, and reset '
      'starts over', (tester) async {
    await _pumpPhone(tester);
    await tester.tap(find.text(orderEmail));
    await tester.pumpAndSettle();
    expect(find.text(_ready), findsOneWidget);

    await tester.tap(find.byTooltip('Reset example'));
    await tester.pumpAndSettle();

    expect(find.text(_ready), findsNothing);
    expect(
      find.text('Paste a customer e-mail into the chat to start an order.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'the order desk takes a backend URL, checks it and switches back',
    (tester) async {
      await _pumpPhone(tester);
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
  await tester.pumpWidget(const OrderDeskApp());
}
