import 'package:example/recipes/on_device/invoices/invoice_app.dart';
import 'package:example/recipes/on_device/invoices/invoice_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tandem/testing.dart';

const _may = <String, Object?>{
  'action': 'archive',
  'recordKind': 'invoice',
  'dateField': 'issued',
  'month': 'may',
  'year': null,
  'restriction': 'none',
};

void main() {
  testWidgets(
    'four title matches become six date matches, archived only after approval',
    (tester) async {
      await _open(tester);
      await tester.enterText(find.byType(TextField), 'May invoice');
      await tester.pumpAndSettle();
      expect(find.text('May hosting invoice'), findsOneWidget);
      expect(find.text('INV-1042'), findsNothing);
      final store = tester.element(find.byType(TextField)).read<InvoiceStore>();
      expect(store.visible, hasLength(4));

      await _ask(tester);
      expect(
        find.text('Archive 6 invoices issued in May 2026?'),
        findsOneWidget,
      );
      expect(find.text("2 don't mention May in the title."), findsOneWidget);
      expect(store.archivedCount, 0);

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(store.archivedCount, 6);
      expect(find.text('April invoice'), findsOneWidget);
      expect(store.active.map((invoice) => invoice.id), [
        'inv-7',
        'inv-8',
        'inv-9',
        'inv-10',
      ]);
      expect(find.text('6 invoices archived'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(store.archivedCount, 0);
      expect(store.visible, hasLength(10));
    },
  );

  testWidgets('an unsupported date does not offer an archive', (tester) async {
    await _open(tester, arguments: {..._may, 'dateField': 'paid'});
    await _ask(tester);
    expect(find.text('Archive 6 invoices issued in May 2026?'), findsNothing);
    expect(
      find.text('For now, try invoices issued in one month.'),
      findsOneWidget,
    );
    expect(
      tester.element(find.byType(TextField)).read<InvoiceStore>().archivedCount,
      0,
    );
  });
}

Future<void> _open(
  WidgetTester tester, {
  Map<String, Object?> arguments = _may,
}) async {
  tester.view.physicalSize = const Size(430, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    InvoiceApp(
      connection: ScriptedAgent([
        (_) => [AgentStep.callTool('interpret_invoice_input', arguments)],
        (_) => const [AgentStep.say('Done.')],
      ]),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('smart-toggle')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField),
    'Archive invoices issued in May',
  );
  await tester.testTextInput.receiveAction(.search);
  await tester.pumpAndSettle();
}
