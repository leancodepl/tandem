import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/app.dart';
import 'package:waypoint/features/booking/booking_cubit.dart';
import 'package:waypoint/features/booking/booking_error.dart';
import 'package:waypoint/features/booking/booking_sheet.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  testWidgets('a booking sheet opens with the latest confirmed trip dates', (
    tester,
  ) async {
    final context = await _openTrip(tester);
    final trip = context.read<TripCubit>();
    final trips = context.read<TripsCubit>();
    final stale = trip.info;
    trips.book(
      stale.id,
      stale.booked.copyWith(homebound: _flightHome(DateTime(2026, 10, 30))),
    );

    await _showSheet(tester, context, stale);

    final booking = _booking(tester);
    expect(booking.form.tripEnd, DateTime(2026, 10, 30, 18, 5));
    expect(_dateField(tester, 'Check-out').last.day, 30);
    expect(() => booking.setCheckOut(DateTime(2026, 10, 30)), returnsNormally);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmed flight dates update the open sheet without replacing its draft',
    (tester) async {
      final context = await _openTrip(tester);
      final trip = context.read<TripCubit>();
      final trips = context.read<TripsCubit>();
      trip.setHomeboundFlight('WA 388', DateTime(2026, 10, 30));
      final confirming = trip.bookChanges();
      await _showSheet(tester, context, trip.info);
      final booking = _booking(tester)
        ..setHotel('Preserved hotel')
        ..setAddress('Berlin address')
        ..setCheckIn(DateTime(2026, 10, 28, 15))
        ..setCheckOut(DateTime(2026, 10, 29))
        ..setTotalPrice(245)
        ..setConfirmation('CONFIRMED-245');
      final form = booking.form;
      final session = _session(tester);
      await tester.pump();
      expect(_submit(tester), isNotNull);
      form.checkOut.setValue(DateTime(2026, 10, 30));
      await tester.pump();
      expect(form.checkOut.error, isA<OutsideTrip>());
      expect(form.value.wasModified, isTrue);
      expect(_submit(tester), isNull);

      await tester.pump(const Duration(milliseconds: 900));
      await confirming;
      await tester.pump();
      await tester.pump();

      expect(identical(_booking(tester), booking), isTrue);
      expect(identical(_booking(tester).form, form), isTrue);
      expect(identical(_session(tester), session), isTrue);
      expect(form.tripEnd, DateTime(2026, 10, 30, 18, 5));
      expect(_dateField(tester, 'Check-in').last.day, 29);
      expect(_dateField(tester, 'Check-out').last.day, 30);
      expect(form.checkOut.error, isNull);
      expect(form.value.wasModified, isTrue);
      booking.setCheckOut(DateTime(2026, 10, 30));
      await tester.pump();
      expect(form.checkOut.fieldValue, DateTime(2026, 10, 30));
      expect(_submit(tester), isNotNull);

      final extended = trips.tripOrNull(trip.info.id);
      if (extended == null) fail('The confirmed trip is still available.');
      trips.book(
        extended.id,
        extended.booked.copyWith(
          homebound: _flightHome(DateTime(2026, 10, 29)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(identical(_booking(tester), booking), isTrue);
      expect(identical(_booking(tester).form, form), isTrue);
      expect(identical(_session(tester), session), isTrue);
      expect(form.tripEnd, DateTime(2026, 10, 29, 18, 5));
      expect(_dateField(tester, 'Check-in').last.day, 28);
      expect(_dateField(tester, 'Check-out').last.day, 29);
      expect(form.checkOut.fieldValue, DateTime(2026, 10, 30));
      expect(form.checkOut.error, isA<OutsideTrip>());
      expect(form.value.wasModified, isTrue);
      expect(_submit(tester), isNull);
      expect(form.hotel.fieldValue, 'Preserved hotel');
      expect(form.address.fieldValue, 'Berlin address');
      expect(form.checkIn.fieldValue, DateTime(2026, 10, 28, 15));
      expect(form.totalPrice.fieldValue, '245');
      expect(form.confirmation.fieldValue, 'CONFIRMED-245');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<BuildContext> _openTrip(WidgetTester tester) async {
  await tester.pumpWidget(const WaypointApp(createAgents: _idleAgents));
  await _settle(tester);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('pushRouteInformation', {'location': '/trips/berlin'}),
    ),
    (data) {},
  );
  await _settle(tester);
  return tester.element(find.byType(TandemScope));
}

Future<void> _showSheet(
  WidgetTester tester,
  BuildContext context,
  Trip trip,
) async {
  unawaited(showBookingSheet(context, connection: _idle(), trip: trip));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

BookingCubit _booking(WidgetTester tester) =>
    tester.element(find.text('Check-out')).read<BookingCubit>();

TandemSession _session(WidgetTester tester) =>
    TandemSessionScope.of(tester.element(find.text('Check-out')));

WPFormDateField<BookingError> _dateField(WidgetTester tester, String label) =>
    tester.widget(
      find.byWidgetPredicate(
        (widget) =>
            widget is WPFormDateField<BookingError> && widget.label == label,
      ),
    );

VoidCallback? _submit(WidgetTester tester) => tester
    .widget<WPSubmit>(
      find.byWidgetPredicate(
        (widget) => widget is WPSubmit && widget.label == 'Add to trip',
      ),
    )
    .onSubmit;

Flight _flightHome(DateTime date) =>
    const FlightSearch().find(FlightNumber('WA 388'), date) ??
    (throw StateError('The flight home exists in the timetable.'));

AgentConnection _idle() =>
    ScriptedAgent.repeating((request) => const [AgentStep.say('Ready.')]);

Agents _idleAgents() => Agents(
  trip: _idle(),
  booking: _idle(),
  plan: _idle(),
  expenses: _idle(),
  arrival: _idle(),
);

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
