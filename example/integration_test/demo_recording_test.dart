import 'package:example/desk/ui/demo_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Plays the demo script of `example/agent/README.md` like a person would, on
// an iPad, against the agent on `localhost:8000`, in `example/agent`: the
// scripted one (`TANDEM_FAKE_LLM=1 uv run order-agent`) or Gemini
// (`uv run order-agent`). Gemini words its answers differently every time, so
// the driver does not wait for sentences: it waits until the screen shows the
// next milestone, and fails naming the milestone it did not see. Run it in
// `example` with
// `fvm flutter test integration_test/demo_recording_test.dart -d <iPad>`.

const _email =
    'Hi, could you send us 40 HDMI cables (2 m) and 12 of the 27-inch '
    'monitors like last time? Delivery to Magazynowa 5, Poznań by Friday '
    'please. Thanks, Marta, Acme Office Supply';
const _empty = 'Paste a customer e-mail into the chat to start an order.';
const _customer = 'Acme Office Supply Sp. z o.o.';
const _cables = 'VC-HDMI-2M';
const _monitor = 'VM-27Q';
const _monitorTaps = 3;
const _newTotal = '16 710.05 PLN';
const _confirmation = 'Looks good, place it';
const _placed = 'Placed as ORD-1042';

// The pauses, so that a person watching can follow, as in the demo video.
const _emptyScreen = Duration(seconds: 4);
const _afterPasting = Duration(seconds: 2);
const _readingAnswer = Duration(seconds: 4);
const _betweenTaps = Duration(milliseconds: 1500);
const _afterTaps = Duration(seconds: 2);
const _readingCard = Duration(seconds: 4);
const _finalScreen = Duration(seconds: 4);

/// How long a milestone may take to show: Gemini needs several answers to fill
/// the order.
const _milestoneTimeout = Duration(seconds: 60);

/// How often to look for it.
const _poll = Duration(milliseconds: 100);

/// The button that sends the message. It reads Stop while the agent works, so
/// finding Send means the agent is done, and the buttons of a card work.
final _send = find.text('Send');

void main() {
  // Frames at full rate, so the highlights fade as they do in the app.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      .fullyLive;

  testWidgets('plays the demo script against the running agent', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    expect(find.text(_empty), findsOneWidget);
    await tester.pump(_emptyScreen);

    await _paste(tester, _email);
    // The total is shown with the lines.
    await _reach(tester, 'the order is filled', [
      find.text(_customer),
      _line(_cables),
      _line(_monitor),
      _send,
    ]);
    await tester.pump(_readingAnswer);

    for (var tap = 0; tap < _monitorTaps; tap++) {
      await tester.tap(_plusOf(_monitor));
      await tester.pump(_betweenTaps);
    }
    expect(
      find.text(_newTotal),
      findsOneWidget,
      reason: 'the total after $_monitorTaps taps on + of $_monitor',
    );
    await tester.pump(_afterTaps);

    await _paste(tester, _confirmation);
    await _reach(tester, 'the approval card', [find.text('Approve'), _send]);
    await tester.pump(_readingCard);
    await tester.tap(find.text('Approve'));
    await _reach(tester, 'the order is placed', [find.text(_placed), _send]);
    await tester.pump(_finalScreen);
  });
}

/// Pastes [text] into the chat field and sends it. It sets the text of the
/// field and does not focus it, which would raise the on-screen keyboard over
/// the screen.
Future<void> _paste(WidgetTester tester, String text) async {
  tester.widget<TextField>(find.byType(TextField)).controller?.text = text;
  await tester.pump(_afterPasting);
  await tester.tap(_send);
  await tester.pump();
}

/// Pumps until [onScreen] all find a widget, or fails after
/// [_milestoneTimeout], naming [milestone] and what is missing.
Future<void> _reach(
  WidgetTester tester,
  String milestone,
  List<Finder> onScreen,
) async {
  var waited = Duration.zero;
  while (!onScreen.every(tester.any)) {
    if (waited >= _milestoneTimeout) {
      final missing = onScreen.where((finder) => !tester.any(finder));
      fail(
        'Milestone "$milestone" not reached within $_milestoneTimeout. '
        'Missing: ${missing.map((f) => f.describeMatch(.zero)).join(', ')}.',
      );
    }
    await tester.pump(_poll);
    waited += _poll;
  }
}

/// The order line of [sku].
Finder _line(String sku) => find.byKey(ValueKey(sku));

/// The + button of the order line of [sku].
Finder _plusOf(String sku) =>
    find.descendant(of: _line(sku), matching: find.byIcon(Icons.add));
