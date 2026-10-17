import 'package:example/desk/ui/demo_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Plays the demo of `example/agent/README.md` on an iPad, slowly enough for a
// viewer to follow. It needs the agent on `localhost:8000`, scripted
// (`TANDEM_FAKE_LLM=1 uv run order-agent`) or Gemini (`uv run order-agent`).
// Gemini words its answers differently every time, so the test waits for
// milestones on the screen, not for sentences. Run it in `example` with
// `fvm flutter test integration_test/demo_recording_test.dart -d <iPad>`.

// Reads Stop while the agent works, so finding Send means the agent is done.
final _send = find.text('Send');

void main() {
  // Frames at full rate, so the highlights fade as they do in the app.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      .fullyLive;

  testWidgets('plays the demo script against the running agent', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    expect(
      find.text('Paste a customer e-mail into the chat to start an order.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));

    await _paste(
      tester,
      'Hi, could you send us 40 HDMI cables (2 m) and 12 of the 27-inch '
      'monitors like last time? Delivery to Magazynowa 5, Poznań by Friday '
      'please. Thanks, Marta, Acme Office Supply',
    );
    await _reach(tester, 'the order is filled', [
      find.text('Acme Office Supply Sp. z o.o.'),
      _line('VC-HDMI-2M'),
      _line('VM-27Q'),
      _send,
    ]);
    await tester.pump(const Duration(seconds: 4));

    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(_plusOf('VM-27Q'));
      await tester.pump(const Duration(milliseconds: 1500));
    }
    expect(
      find.text('16 710.05 PLN'),
      findsOneWidget,
      reason: 'the total after 3 taps on + of VM-27Q',
    );
    await tester.pump(const Duration(seconds: 2));

    await _paste(tester, 'Looks good, place it');
    await _reach(tester, 'the approval card', [find.text('Approve'), _send]);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Approve'));
    await _reach(tester, 'the order is placed', [
      find.text('Placed as ORD-1042'),
      _send,
    ]);
    await tester.pump(const Duration(seconds: 4));
  });
}

/// Sets the text without focusing the field, which would raise the on-screen
/// keyboard over the screen.
Future<void> _paste(WidgetTester tester, String text) async {
  tester.widget<TextField>(find.byType(TextField)).controller?.text = text;
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(_send);
  await tester.pump();
}

Future<void> _reach(
  WidgetTester tester,
  String milestone,
  List<Finder> onScreen,
) async {
  const timeout = Duration(seconds: 60);
  const poll = Duration(milliseconds: 100);
  var waited = Duration.zero;
  while (!onScreen.every(tester.any)) {
    if (waited >= timeout) {
      final missing = onScreen.where((finder) => !tester.any(finder));
      fail(
        'Milestone "$milestone" not reached within $timeout. '
        'Missing: ${missing.map((f) => f.describeMatch(.zero)).join(', ')}.',
      );
    }
    await tester.pump(poll);
    waited += poll;
  }
}

Finder _line(String sku) => find.byKey(ValueKey(sku));

Finder _plusOf(String sku) =>
    find.descendant(of: _line(sku), matching: find.byIcon(Icons.add));
