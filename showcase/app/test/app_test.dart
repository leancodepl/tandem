import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/app.dart';
import 'package:waypoint/features/booking/booking_cubit.dart';
import 'package:waypoint/features/booking/booking_form_controller.dart';
import 'package:waypoint/features/expenses/expenses_report/expenses_report_form_controller.dart';
import 'package:waypoint/features/plan_trip/plan_trip_cubit.dart';
import 'package:waypoint/features/trip/trip_assistant_panel.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_scripted_agent/waypoint_scripted_agent.dart';

void main() {
  testWidgets(
    'an e-mail that moves the workshop gets the trip fixed and booked',
    (tester) async {
      await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
      expect(find.text('NEEDS YOU'), findsOneWidget);

      await tester.tap(find.text('Review the trip'));
      await _settle(tester);

      // The assistant fits the trip around the e-mail without being asked.
      expect(find.text('Change 2 bookings'), findsOneWidget);
      expect(find.text('Was Thu 29 Oct, 18:05'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await _settle(tester);

      expect(find.text('Booked · confirmation WP-48243'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Booked · confirmation WP-48243'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);

      expect(find.text('NEEDS YOU'), findsOneWidget);
      expect(find.text('Copenhagen · A hotel to add'), findsOneWidget);
      expect(find.textContaining('Workshop moves to Friday'), findsNothing);
      // The marks hide on a timer.
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets('a hotel confirmation in the inbox joins its trip', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await tester.tap(find.text('Inbox'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Add to trip'));
    await _settle(tester);
    await tester.tap(find.text('Add to trip'));
    await _settle(tester);

    expect(
      find.text('Filled in from the e-mail. Check it before you add it.'),
      findsOneWidget,
    );

    // The form's button, over the inbox's.
    await tester.tap(find.text('Add to trip').last);
    await _settle(tester);

    expect(find.text('COPENHAGEN'), findsOneWidget);
    expect(find.text('Havnegade Loft'), findsOneWidget);
    expect(find.text('No hotel yet'), findsNothing);
  });

  testWidgets('a field the traveller fills by hand enables Add to trip', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await _fillHotelFromInbox(tester);

    await _enterInto(tester, 'Hotel', '');

    expect(_onSubmit(tester), isNull);
    expect(find.text('Still missing: the hotel.'), findsOneWidget);

    await _enterInto(tester, 'Hotel', 'Havnegade Harbour Loft');

    expect(_onSubmit(tester), isNotNull);
  });

  testWidgets(
    'the traveller corrects what the agent filled before adding the hotel',
    (tester) async {
      await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
      await _fillHotelFromInbox(tester);

      bool priceMarked() => tester
          .widget<FormAmountField<BookingError>>(
            find.byType(FormAmountField<BookingError>),
          )
          .marked;

      expect(priceMarked(), isTrue);

      await _enterInto(tester, 'Price', '190');

      expect(priceMarked(), isFalse);
      expect(_onSubmit(tester), isNotNull);

      await tester.tap(find.text('Add to trip').last);
      await _settle(tester);

      final trips = tester.element(find.text('COPENHAGEN')).read<TripsCubit>();
      expect(trips.tripOrNull('copenhagen')?.booked.hotel?.nightly, 190);
    },
  );

  testWidgets('the check-out calendar offers no day a stay cannot end on', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await _fillHotelFromInbox(tester);

    // The trip starts on the 18th, so no stay ends on it.
    await _pickDay(tester, 'Check-out', '18');

    final booking = tester.element(find.text('Check-out')).read<BookingCubit>();
    expect(booking.form.checkOut.fieldValue, DateTime(2026, 11, 19));
    expect(find.textContaining('must be after'), findsNothing);
    expect(_onSubmit(tester), isNotNull);
  });

  testWidgets('on a phone the booking form stays above the keyboard', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await _fillHotelFromInbox(tester);
    // An iPhone's keyboard, 336 points high.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    addTearDown(tester.view.resetViewInsets);
    await _settle(tester);

    final keyboardTop = tester.view.physicalSize.height / 3 - 336;
    final confirmation = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is FormTextField && widget.label == 'Confirmation',
      ),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(confirmation);
    await _settle(tester);

    expect(tester.getRect(confirmation).bottom, lessThan(keyboardTop));
    expect(
      tester.getRect(find.text('Add to trip').last).bottom,
      lessThan(keyboardTop),
    );
  });

  testWidgets('an invitation becomes a trip planned within the policy', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await tester.tap(find.text('Plan the trip'));
    await _settle(tester);

    // Why it chose so, in the agent's words.
    expect(
      find.textContaining("Planned from Mira's invitation"),
      findsOneWidget,
    );
    // Further down the form than the phone shows.
    expect(
      find.textContaining('8 min on foot', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('WA 517', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Book trip'));
    await _settle(tester);

    expect(find.text('VIENNA'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);

    expect(find.textContaining('Invitation from Alpenlicht'), findsNothing);
    // Last in the list, by its date.
    await tester.scrollUntilVisible(find.text('VIENNA'), 300);
    expect(find.text('VIENNA'), findsOneWidget);
  });

  testWidgets("the traveller's city replaces the one the assistant set", (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Plan a trip'));
    await _settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(WaypointTextField),
        matching: find.byType(TextField),
      ),
      'The Alpenlicht workshop in Vienna',
    );
    await tester.pump();
    await tester.tap(find.text('Plan'));
    await _settle(tester);
    final plan = tester.element(find.text('Berlin')).read<PlanTripCubit>();
    expect(plan.state.marked, contains(PlanTripInput.city));

    await tester.tap(find.text('Berlin'));
    await _settle(tester);

    expect(plan.form.city.fieldValue, 'Berlin');
    expect(plan.state.marked, isNot(contains(PlanTripInput.city)));
    expect(plan.missing, [
      PlanPart.outbound,
      PlanPart.homebound,
      PlanPart.hotel,
    ]);
    // The traveller asks again for the new city.
    expect(
      tester
          .widget<WaypointButton>(find.widgetWithText(WaypointButton, 'Plan'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets("an invitation's city stays the invitation's", (tester) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Plan the trip'));
    await _settle(tester);

    await tester.tap(find.text('Berlin'));
    await _settle(tester);

    final plan = tester.element(find.text('Berlin')).read<PlanTripCubit>();
    expect(plan.form.city.fieldValue, 'Vienna');
    expect(plan.missing, isEmpty);
  });

  testWidgets('the receipts of a past trip become a submitted report', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await tester.tap(find.text('Expenses'));
    await _settle(tester);
    await tester.tap(find.text('PARIS'));
    await _settle(tester);

    // The dinner goes over the meal limit; the agent claims what is left.
    final dinner = tester.widget<FormAmountField<ClaimError>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is FormAmountField &&
            widget.label.startsWith('Bistrot du Canal'),
      ),
    );
    expect(dinner.field.fieldValue, '42');
    expect(find.text('€29 not paid back'), findsOneWidget);
    expect(
      find.text('The assistant asks to submit the report for €130.'),
      findsOneWidget,
    );

    expect(find.byIcon(Icons.edit_outlined), findsWidgets);

    await tester.tap(find.text('Approve'));
    await _settle(tester);

    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('ER-PARIS-130'), findsOneWidget);
    // A submitted claim reads as a plain value.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets("a claim changed while the submit waits voids the assistant's "
      'ask', (tester) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Expenses'));
    await _settle(tester);
    await tester.tap(find.text('PARIS'));
    await _settle(tester);
    expect(find.textContaining('Submit the report?'), findsOneWidget);

    await _enterInto(tester, 'G7 Taxi', '50', labelStartsWith: true);

    expect(find.text('Approve'), findsNothing);
    expect(find.textContaining('Submit the report?'), findsNothing);
    expect(_onSubmit(tester), isNotNull);
  });

  testWidgets('Back from a report opened on Trips returns to Trips', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await tester.scrollUntilVisible(find.text('PARIS'), 300);
    await tester.tap(find.text('PARIS'));
    await _settle(tester);

    expect(
      find.text('The assistant asks to submit the report for €130.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);

    expect(find.text('PAST'), findsOneWidget);
    expect(find.text('EXPENSES'), findsNothing);
  });

  testWidgets('the agent draws the arrival day and its buttons book a ride', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await _openArrivalDay(tester);

    // Drawn with Waypoint's widgets, from what the screen lists.
    expect(find.text('After you land'), findsOneWidget);
    expect(find.text('Kickoff with Studio Kraft'), findsOneWidget);
    expect(
      find.textContaining('the policy allows a taxi only'),
      findsOneWidget,
    );

    await tester.tap(find.text('Book'));
    await _settle(tester);

    expect(
      find.text('Book the S-Bahn for €4 on the company card?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Approve'));
    await _settle(tester);

    expect(find.text('S-Bahn ticket AB, valid for 2 hours'), findsOneWidget);
    expect(find.textContaining('Booked: S-Bahn ticket AB'), findsOneWidget);
  });

  testWidgets('a change of the traveller voids the request to book, and the '
      'assistant asks again', (tester) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Review the trip'));
    await _settle(tester);

    await _openFlightHome(tester, 'WA 388');
    await _tapOption(tester, find.text('WA 390'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(_voided, skipOffstage: false), findsOneWidget);

    await _settle(tester);

    expect(find.textContaining('The trip changed. Book'), findsOneWidget);
    expect(
      find.text(
        'The trip changed. Replaced by the request below.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text('Change 2 bookings', skipOffstage: false),
      findsNWidgets(2),
    );
  });

  testWidgets('a voided request is asked again only once', (tester) async {
    final trip = ScriptedAgent.repeating(_asksOnce);
    await _pumpApp(
      tester,
      WaypointApp(
        createAgents: () => Agents(
          trip: trip,
          booking: scriptedBookingAgent(),
          plan: scriptedPlanAgent(),
          expenses: scriptedExpensesAgent(),
          arrival: scriptedArrivalAgent(),
        ),
      ),
    );
    await tester.tap(find.text('Review the trip'));
    await _settle(tester);

    await _openFlightHome(tester, 'WA 388');
    await _tapOption(tester, find.text('WA 390'));
    await tester.pump(const Duration(milliseconds: 500));
    for (var wait = 0; wait < 5; wait++) {
      await _settle(tester);
    }

    expect(find.text(_voided, skipOffstage: false), findsOneWidget);
    expect([
      for (final request in trip.requests)
        for (final note in AgentRequest(request).newNotes)
          if ('$note'.contains(_reask)) note,
    ], hasLength(1));
  });

  testWidgets('the traveller rejects the changes the assistant asks to book', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Review the trip'));
    await _settle(tester);

    await tester.tap(find.text('Reject'));
    await _settle(tester);

    expect(find.text('Rejected', skipOffstage: false), findsOneWidget);
    expect(find.text("OK, I won't book them."), findsOneWidget);
    expect(find.textContaining('Booked · confirmation'), findsNothing);
  });

  testWidgets('a rejected expense report stays unsubmitted', (tester) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Expenses'));
    await _settle(tester);
    await tester.tap(find.text('PARIS'));
    await _settle(tester);

    await tester.tap(find.text('Reject'));
    await _settle(tester);

    expect(find.text('Submitted'), findsNothing);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('a rejected ride is not booked', (tester) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await _openArrivalDay(tester);

    await tester.tap(find.text('Book'));
    await _settle(tester);
    await tester.tap(find.text('Reject'));
    await _settle(tester);

    expect(find.textContaining('S-Bahn ticket AB'), findsNothing);
    expect(find.text('Book'), findsOneWidget);
  });

  testWidgets('the flight home is picked from the flights the policy allows', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Review the trip'));
    await _settle(tester);

    await _openFlightHome(tester, 'WA 388');

    // WA 382 and WA 386 leave before the workshop ends.
    expect(find.text('Too early'), findsNWidgets(2));

    await _tapOption(tester, find.text('Too early').first);
    await _settle(tester);

    expect(find.text('Flight WA 388'), findsOneWidget);
    expect(find.text('Too early'), findsNWidgets(2));

    await _tapOption(tester, find.text('WA 390'));
    await _settle(tester);

    expect(find.text('Flight WA 390'), findsOneWidget);
    expect(find.text('Too early'), findsNothing);
  });

  testWidgets('a flight home the policy rules out after it shows says why', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.tap(find.text('Review the trip'));
    await _settle(tester);
    await _openFlightHome(tester, 'WA 388');
    final option = find.text('WA 390');
    await tester.ensureVisible(option);
    await tester.pump();

    // The workshop moves later before the tap lands.
    tester
        .element(option)
        .read<TripCubit>()
        .moveMeeting('workshop', DateTime(2026, 10, 30, 20, 15));
    await tester.tap(option);
    await tester.pump();

    expect(
      find.text(
        'WA 390 leaves less than an hour after the Design workshop ends',
      ),
      findsOneWidget,
    );
  });

  testWidgets('on an iPad the assistant works beside the trip', (tester) async {
    await _pumpApp(
      tester,
      const WaypointApp(createAgents: _scriptedAgents),
      size: const Size(2732, 2048),
      ratio: 2,
    );

    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.text('Review the trip'));
    await _settle(tester);

    expect(find.byType(AssistantPanel), findsOneWidget);
    // Beside the assistant, the bar keeps the changes while the request waits.
    expect(find.text('Change 2 bookings'), findsOneWidget);
    expect(find.text('2 changes not booked'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _settle(tester);
    await tester.tap(find.text('Inbox'));
    await _settle(tester);
    await tester.tap(find.text('Add to trip'));
    await _settle(tester);

    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('a hotel from an e-mail joins the trip, marked for a while', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));
    await tester.scrollUntilVisible(find.text('COPENHAGEN'), 300);
    await tester.tap(find.text('COPENHAGEN'));
    await _settle(tester);

    await tester.ensureVisible(find.text('Add from e-mail'));
    await _settle(tester);
    await tester.tap(find.text('Add from e-mail'));
    await _settle(tester);
    await tester.tap(find.text('Your booking is confirmed: 55120873'));
    await _settle(tester);
    await tester.tap(find.text('Add to trip'));
    await _settle(tester);

    bool marked() => tester
        .widget<WaypointCard>(
          find.ancestor(
            of: find.text('Havnegade Loft'),
            matching: find.byType(WaypointCard),
          ),
        )
        .marked;

    expect(find.text('No hotel yet'), findsNothing);
    expect(marked(), isTrue);

    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);

    expect(marked(), isFalse);
  });
  testWidgets('a link to a trip that is not there leads to the trips', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await _openLink(tester, '/trips/rome');

    expect(find.text('This trip is not in Waypoint.'), findsOneWidget);

    await tester.tap(find.text('Your trips'));
    await _settle(tester);

    expect(find.text('NEEDS YOU'), findsOneWidget);
  });

  testWidgets('a link to an invitation that is not there leads to the trips', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await _openLink(tester, '/trips/plan-trip?invitation=rome');

    expect(find.text('This invitation is not in your inbox.'), findsOneWidget);

    await tester.tap(find.text('Your trips'));
    await _settle(tester);

    expect(find.text('NEEDS YOU'), findsOneWidget);
  });

  testWidgets('a link to an arrival day not drawn yet leads to its trip', (
    tester,
  ) async {
    await _pumpApp(tester, const WaypointApp(createAgents: _scriptedAgents));

    await _openLink(tester, '/trips/copenhagen/arrival');

    expect(find.text('No arrival day for this trip yet.'), findsOneWidget);

    await tester.tap(find.text('Back to the trip'));
    await _settle(tester);

    expect(find.text('COPENHAGEN'), findsOneWidget);
  });
}

const _voided = 'No longer valid. The trip changed after the assistant asked.';

/// What the app notes for the agent when it asks again.
const _reask = 'changed the trip on the screen';

/// A trip agent that answers the app's request to ask again without asking.
List<AgentStep> _asksOnce(Map<String, Object?> raw) {
  final request = AgentRequest(raw);
  if (request.isUserMessage) {
    if ('${request.newNotes}'.contains(_reask)) {
      return const [AgentStep.say('Noted.')];
    }
    return const [
      AgentStep.callTool('set_hotel_nights', {'nights': 2}),
    ];
  }
  return const [AgentStep.callTool('book_changes')];
}

Agents _scriptedAgents() => Agents(
  trip: scriptedTripAgent(),
  booking: scriptedBookingAgent(),
  plan: scriptedPlanAgent(),
  expenses: scriptedExpensesAgent(),
  arrival: scriptedArrivalAgent(),
);

/// Pumps [app] on an iPhone, or on a screen of [size] pixels at [ratio].
Future<void> _pumpApp(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(1179, 2556),
  double ratio = 3,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await _settle(tester);
}

/// Two seconds in frames, so that the animations end. `pumpAndSettle` would
/// wait forever on the progress bar of the agent at work.
/// Opens the Copenhagen hotel's confirmation from the inbox and lets the
/// agent fill the booking form from it.
Future<void> _fillHotelFromInbox(WidgetTester tester) async {
  await tester.tap(find.text('Inbox'));
  await _settle(tester);
  await tester.ensureVisible(find.text('Add to trip'));
  await _settle(tester);
  await tester.tap(find.text('Add to trip'));
  await _settle(tester);
}

/// Types [text] into the form's field under [label], as the traveller.
Future<void> _enterInto(
  WidgetTester tester,
  String label,
  String text, {
  bool labelStartsWith = false,
}) async {
  bool labelled(String shown) =>
      labelStartsWith ? shown.startsWith(label) : shown == label;
  final input = find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          (widget is FormTextField && labelled(widget.label)) ||
          (widget is FormAmountField && labelled(widget.label)),
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await _settle(tester);
}

/// Picks [day] of the month in the calendar of the booking form's field
/// under [label], as the traveller.
Future<void> _pickDay(WidgetTester tester, String label, String day) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is FormDateField && widget.label == label,
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await _settle(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text(day),
    ),
  );
  await tester.tap(find.text('OK'));
  await _settle(tester);
}

/// The form's submit, null while it is disabled.
VoidCallback? _onSubmit(WidgetTester tester) =>
    tester.widget<WaypointSubmit>(find.byType(WaypointSubmit)).onSubmit;

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openArrivalDay(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('BERLIN'), 300);
  await tester.tap(find.text('BERLIN'));
  await _settle(tester);
  await tester.ensureVisible(find.text('Arrival day'));
  await _settle(tester);
  await tester.tap(find.text('Arrival day'));
  await _settle(tester);
}

Future<void> _openFlightHome(WidgetTester tester, String number) async {
  await tester.ensureVisible(find.text('Flight $number'));
  await _settle(tester);
  await tester.tap(find.text('Flight $number'));
  await _settle(tester);
}

/// Taps an option of the open flight picker. The picker scrolls itself into
/// view as it opens, but the test's frames are too coarse for that.
Future<void> _tapOption(WidgetTester tester, Finder option) async {
  await tester.ensureVisible(option);
  await tester.pump();
  await tester.tap(option);
}

/// Opens [location] as the platform does for a deep link.
Future<void> _openLink(WidgetTester tester, String location) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': location}),
    ),
    (_) {},
  );
  await _settle(tester);
}
