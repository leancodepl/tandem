import 'package:example/agent_chat.dart';
import 'package:example/apple_foundation_models/try_it.dart' as pilot;
import 'package:example/shopping_list/shopping_list.dart'
    show ShoppingListScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

const _channel = MethodChannel('tandem/apple_foundation_models');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('model availability gates the list and can be retried', (
    tester,
  ) async {
    var available = false;
    _handle(
      (call) async => {
        'available': available,
        'reason': available
            ? 'Ready.'
            : 'Enable Apple Intelligence in Settings.',
      },
    );
    await tester.pumpWidget(const SizedBox());
    pilot.main();
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingListScreen), findsNothing);
    expect(find.text('Enable Apple Intelligence in Settings.'), findsOneWidget);

    available = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(ShoppingListScreen), findsOneWidget);
    expect(find.text('Add milk to the list.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native model failure shows its reason and a reset action', (
    tester,
  ) async {
    _handle(
      (call) async => switch (call.method) {
        'availability' => {'available': true, 'reason': 'Ready.'},
        'run' => throw PlatformException(
          code: 'MODEL',
          message: 'The on-device model needs more memory. Try again later.',
        ),
        _ => null,
      },
    );
    await tester.pumpWidget(const SizedBox());
    pilot.main();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AgentChat),
        matching: find.byType(TextField),
      ),
      'Add milk',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<AgentRunException>());
    expect(
      find.text('The on-device model needs more memory. Try again later.'),
      findsOneWidget,
    );
    expect(
      find.text('Reset pilot to start a fresh conversation.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Reset pilot'));
    await tester.pumpAndSettle();

    expect(find.text('Add milk to the list.'), findsOneWidget);
    expect(
      find.text('Reset pilot to start a fresh conversation.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

void _handle(Future<Object?> Function(MethodCall call) handler) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, handler);
