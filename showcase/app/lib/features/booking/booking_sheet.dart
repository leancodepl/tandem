import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/dates/days_after.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/booking/booking_cubit.dart';
import 'package:waypoint/features/booking/booking_draft.dart';
import 'package:waypoint/features/booking/booking_error.dart';
import 'package:waypoint/features/booking/booking_form_controller.dart';
import 'package:waypoint/features/booking/booking_presentation_event.dart';
import 'package:waypoint/features/inbox/inbox_received.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/features/trips/trips_state.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Booking');

/// Selects [email], or lets the traveller choose a confirmation.
/// Returns the hotel they added, or null.
Future<HotelStay?> showBookingSheet(
  BuildContext context, {
  required AgentConnection connection,
  required Trip trip,
  ForwardedEmail? email,
}) {
  final sheet = _BookingSheet(
    connection: connection,
    trip: trip,
    emails: [
      for (final email in context.read<Inbox>().emails)
        if (email case ForwardedEmail(news: HotelConfirmation())
            when email.tripId == trip.id && !email.isDoneIn(trip.booked))
          email,
    ],
    email: email,
  );
  return showWPSheet(context, child: sheet);
}

final class const _BookingSheet({
  required final AgentConnection connection,
  required final Trip trip,
  required final List<ForwardedEmail> emails,
  required final ForwardedEmail? email,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (context) {
          final booked =
              context.read<TripsCubit>().tripOrNull(trip.id)?.booked ??
              trip.booked;
          return BookingFormController(
            tripStart: booked.outbound.departs,
            tripEnd: booked.homebound.departs,
          );
        },
      ),
      BlocProvider(
        create: (context) =>
            BookingCubit(form: context.read<BookingFormController>()),
      ),
      BlocListener<TripsCubit, TripsState>(
        listener: (context, _) {
          final booked = context.read<TripsCubit>().tripOrNull(trip.id)?.booked;
          if (booked == null) return;
          context.read<BookingFormController>().updateTripDates(
            start: booked.outbound.departs,
            end: booked.homebound.departs,
          );
        },
      ),
      const BlocPresentationListener<BookingCubit, BookingPresentationEvent>(
        listener: _close,
      ),
    ],
    child: Builder(
      builder: (context) => TandemScope.connected(
        surface: (context) => context.read<BookingCubit>(),
        connection: connection,
        approvals: const .none(),
        onEvent: (context, event, session) => _log.agentEvent(event),
        child: _BookingSheetContent(emails: emails, email: email),
      ),
    ),
  );

  static void _close(BuildContext context, BookingPresentationEvent event) {
    switch (event) {
      case BookingPresentationEventAdded(:final stay):
        context.router.pop(stay);
    }
  }
}

final class const _BookingSheetContent({
  required final List<ForwardedEmail> emails,
  required final ForwardedEmail? email,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .stretch,
    children: [
      Padding(
        padding: const .fromLTRB(24, 22, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(context.l10n.bookingTitle, style: WPTextStyle.title),
            ),
            WPCloseButton(onPressed: context.router.maybePop),
          ],
        ),
      ),
      Expanded(
        child: _BookingForm(emails: emails, email: email),
      ),
    ],
  );
}

final class const _BookingForm({
  required final List<ForwardedEmail> emails,
  required final ForwardedEmail? email,
}) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final chosen = useState(email);
    final asked = useState(false);

    final form = context.watch<BookingFormController>();
    useListenable(form.onValuesChanged);
    final session = TandemSessionScope.of(context);
    final cubit = context.watch<BookingCubit>();
    final busy = session.status.isWorking;
    final l10n = context.l10n;
    final missing = form.missing;
    final stillMissing = l10n.stillMissing(
      missing
          .map((part) => l10n.bookingPart(part.name))
          .join(l10n.listSeparator),
    );
    final status = switch ((busy, asked.value)) {
      (true, _) => l10n.bookingReading,
      (_, true) when missing.isEmpty => l10n.bookingFilled,
      (_, true) => stillMissing,
      (_, false) when form.value.wasModified && missing.isNotEmpty =>
        stillMissing,
      _ => null,
    };
    final shownEmails = switch (chosen.value) {
      final selected? => [selected],
      null => emails,
    };

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const .fromLTRB(24, 12, 24, 24),
            keyboardDismissBehavior: .onDrag,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                alignment: .topCenter,
                child: Column(
                  crossAxisAlignment: .stretch,
                  spacing: 10,
                  children: [
                    Text(
                      chosen.value == null
                          ? l10n.bookingPick
                          : l10n.bookingFromEmails,
                      style: WPTextStyle.label,
                    ),
                    for (final email in shownEmails)
                      WPMailCard(
                        from: email.from,
                        subject: email.subject,
                        selected: chosen.value == email,
                        onTap: busy || chosen.value == email
                            ? null
                            : () => chosen.value = email,
                        trailing: chosen.value == email
                            ? WPTextButton(
                                l10n.changeEmail,
                                onPressed: busy || session.failure != null
                                    ? null
                                    : () {
                                        chosen.value = null;
                                        asked.value = false;
                                      },
                              )
                            : Text(
                                l10n.received(
                                  email.received,
                                  today: context.watch<Traveller>().today,
                                ),
                                style: WPTextStyle.label,
                              ),
                      ),
                    if (chosen.value case final email?)
                      WPButton(
                        l10n.bookingFillFromEmail,
                        onPressed:
                            busy ||
                                cubit.state.adding ||
                                session.failure != null
                            ? null
                            : () {
                                cubit.clear();
                                asked.value = true;
                                session.send(
                                  'Fill in the hotel booking from this confirmation e-mail:\n\n'
                                  '${email.body}',
                                );
                              },
                      ),
                  ],
                ),
              ),
              switch (session.failure) {
                final failure? => WPInlineError(
                  l10n.agentFailure(failure),
                  onRetry: session.retry,
                ),
                null => WPWorkStatus(status, working: busy),
              },
              const SizedBox(height: 18),
              _BookingFields(enabled: !busy),
            ],
          ),
        ),
        WPActionBar(
          gutter: 24,
          child: WPSubmit(
            label: cubit.state.adding ? l10n.adding : l10n.addToTrip,
            busy: cubit.state.adding,
            onSubmit: cubit.ready && !busy
                ? () async {
                    await cubit.add();
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

final class const _BookingFields({required final bool enabled})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final form = context.watch<BookingFormController>();
    final cubit = context.watch<BookingCubit>();
    final marked = cubit.state.marked;
    final draft = form.draft;
    final nights = draft.nights;
    final l10n = context.l10n;
    // A stay takes a night: no check-in on the trip's last day, and no
    // check-out on its first.
    return WPGroup(
      children: [
        WPFormTextField(
          field: form.hotel,
          label: l10n.hotel,
          enabled: enabled,
          textCapitalization: .words,
          marked: marked.contains(BookingPart.hotel),
          order: 0,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.hotel),
        ),
        WPFormTextField(
          field: form.address,
          label: l10n.bookingAddress,
          enabled: enabled,
          textCapitalization: .words,
          maxLines: null,
          marked: marked.contains(BookingPart.address),
          order: 1,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.address),
        ),
        WPFormDateField(
          field: form.checkIn,
          label: l10n.bookingCheckIn,
          format: l10n.dayTime,
          first: form.tripStart,
          last: daysAfter(form.tripEnd, -1),
          fromDay: form.checkInOn,
          withTime: true,
          enabled: enabled,
          marked: marked.contains(BookingPart.checkIn),
          order: 2,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.checkIn),
        ),
        WPFormDateField(
          field: form.checkOut,
          label: l10n.bookingCheckOut,
          format: (day) => switch (nights) {
            final nights? when nights >= 1 => l10n.bookingCheckOutDay(
              l10n.day(day),
              nights,
            ),
            _ => l10n.day(day),
          },
          first: daysAfter(form.tripStart, 1),
          last: form.tripEnd,
          initial: switch (draft.checkIn) {
            final checkIn? => daysAfter(checkIn, 1),
            null => null,
          },
          enabled: enabled,
          marked: marked.contains(BookingPart.checkOut),
          order: 3,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.checkOut),
        ),
        WPFormAmountField(
          field: form.totalPrice,
          label: l10n.bookingPrice,
          symbol: l10n.currencySymbol(supportedCurrency),
          enabled: enabled,
          marked: marked.contains(BookingPart.price),
          order: 4,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.price),
        ),
        WPFormTextField(
          field: form.confirmation,
          label: l10n.bookingConfirmation,
          enabled: enabled,
          textCapitalization: .characters,
          autocorrect: false,
          textInputAction: .done,
          marked: marked.contains(BookingPart.confirmation),
          order: 5,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.confirmation),
        ),
      ],
    );
  }
}

extension on AppLocalizations {
  String bookingError(BookingError error) => switch (error) {
    OutsideTrip(day: final outside, :final tripStart, :final tripEnd) =>
      bookingOutsideTrip(day(outside), dayRange(tripStart, tripEnd)),
    CheckInNotBeforeCheckOut(:final checkOut) =>
      bookingCheckInNotBeforeCheckOut(day(checkOut)),
    CheckOutNotAfterCheckIn(:final checkIn) => bookingCheckOutNotAfterCheckIn(
      day(checkIn),
    ),
    PriceNotPositive() => bookingPriceNotPositive,
  };
}
