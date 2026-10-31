import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';

void main() {
  testWidgets('the calendar opens on the held civil day', (tester) async {
    final field = AdvancedFieldController<DateTime?, String>(
      initialValue: DateTime.utc(2026, 10, 29, 23, 30),
    );
    addTearDown(field.dispose);
    await _pumpField(tester, field);

    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).initialDate,
      DateTime(2026, 10, 29),
    );
  });

  testWidgets('a read-only field ignores a calendar already open', (tester) async {
    final held = DateTime(2026, 10, 28);
    final field = AdvancedFieldController<DateTime?, String>(initialValue: held);
    addTearDown(field.dispose);
    var edits = 0;
    await _pumpField(tester, field, onEdited: () => edits++);
    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('29'));
    field.markReadOnly();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(field.fieldValue, held);
    expect(edits, 0);
  });

  testWidgets('a replaced field ignores its old calendar result', (tester) async {
    final old = AdvancedFieldController<DateTime?, String>(
      initialValue: DateTime(2026, 10, 28),
    );
    final replacement = AdvancedFieldController<DateTime?, String>(
      initialValue: DateTime(2026, 10, 30),
    );
    addTearDown(replacement.dispose);
    var edits = 0;
    await _pumpField(tester, old, onEdited: () => edits++);
    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('29'));
    await _pumpField(tester, replacement, onEdited: () => edits++);
    old.dispose();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(replacement.fieldValue, DateTime(2026, 10, 30));
    expect(edits, 0);
  });
}

Future<void> _pumpField(
  WidgetTester tester,
  AdvancedFieldController<DateTime?, String> field, {
  VoidCallback? onEdited,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: FormDateField(
        field: field,
        label: 'Check-in',
        format: (at) => at.toIso8601String(),
        first: DateTime(2026, 10, 28),
        last: DateTime(2026, 10, 30),
        enabled: true,
        marked: false,
        order: 0,
        onEdited: onEdited,
      ),
    ),
  ),
);
