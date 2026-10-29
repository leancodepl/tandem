import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:tandem/tandem.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/common/logging/agent_event_log.dart';
import 'package:waypoint/common/tandem/agent_failure.dart';
import 'package:waypoint/common/tandem/session_status.dart';
import 'package:waypoint/features/booking/booking_cubit.dart';
import 'package:waypoint/features/booking/booking_form_controller.dart';
import 'package:waypoint/features/inbox/inbox_received.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Booking');

/// Opens the booking form that a forwarded confirmation e-mail fills in,
/// without a chat: [email] at once, or the one the traveller picks of the
/// trip's confirmations. Returns the hotel the traveller added, or null.
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
  return showWaypointSheet(context, child: sheet);
}

final class const _BookingSheet({
  required final AgentConnection connection,
  required final Trip trip,
  required final List<ForwardedEmail> emails,
  required final ForwardedEmail? email,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => BookingFormController(
      tripStart: trip.booked.outbound.departs,
      tripEnd: trip.booked.homebound.departs,
    ),
    child: BlocProvider(
      create: (context) =>
          BookingCubit(form: context.read<BookingFormController>()),
      child: BlocPresentationListener<BookingCubit, BookingPresentationEvent>(
        listener: _close,
        child: Builder(
          builder: (context) => TandemScope.connected(
            surface: (context) => context.read<BookingCubit>(),
            connection: connection,
            approvals: const .none(),
            onEvent: (context, event, session) => _log.agentEvent(event),
            child: _BookingSheetContent(emails: emails, email: email),
          ),
        ),
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
              child: Text(context.l10n.bookingTitle, style: AppText.title),
            ),
            WaypointCloseButton(onPressed: context.router.maybePop),
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
    final chosen = useState<ForwardedEmail?>(null);

    void read(ForwardedEmail email, TandemSession session) {
      chosen.value = email;
      session.send(
        'Fill in the hotel booking from this confirmation e-mail:\n\n'
        '${email.body}',
      );
    }

    useEffect(() {
      if (email case final email?) {
        // Once the session is in scope: it starts with the sheet.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            read(email, TandemSessionScope.of(context));
          }
        });
      }
      return null;
    }, const []);

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
    final status = switch ((busy, chosen.value)) {
      (true, _) => l10n.bookingReading,
      (_, _?) when missing.isEmpty => l10n.bookingFilled,
      (_, _?) => stillMissing,
      (_, null) when form.value.wasModified && missing.isNotEmpty =>
        stillMissing,
      _ => null,
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
                      style: AppText.label,
                    ),
                    for (final email in emails)
                      if (chosen.value == null || chosen.value == email)
                        WaypointMailCard(
                          from: email.from,
                          subject: email.subject,
                          selected: chosen.value == email,
                          onTap: busy || chosen.value == email
                              ? null
                              : () => read(email, session),
                          trailing: chosen.value == email
                              ? WaypointTextButton(
                                  l10n.changeEmail,
                                  onPressed: busy || session.failure != null
                                      ? null
                                      : () {
                                          chosen.value = null;
                                          cubit.clear();
                                        },
                                )
                              : Text(
                                  l10n.received(
                                    email.received,
                                    today: context.watch<Traveller>().today,
                                  ),
                                  style: AppText.label,
                                ),
                        ),
                  ],
                ),
              ),
              switch (session.failure) {
                final failure? => InlineError(
                  l10n.agentFailure(failure),
                  onRetry: session.retry,
                ),
                null => WorkStatus(status, working: busy),
              },
              const SizedBox(height: 18),
              _BookingFields(enabled: !busy),
            ],
          ),
        ),
        WaypointActionBar(
          gutter: 24,
          child: WaypointSubmit(
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
    return WaypointGroup(
      children: [
        FormTextField(
          field: form.hotel,
          label: l10n.hotel,
          enabled: enabled,
          textCapitalization: .words,
          marked: marked.contains(BookingPart.hotel),
          order: 0,
          translateError: l10n.bookingError,
          onEdited: () => cubit.unmark(.hotel),
        ),
        FormTextField(
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
        FormDateField(
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
        FormDateField(
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
        FormAmountField(
          field: form.totalPrice,
          label: l10n.bookingPrice,
          symbol: l10n.euroSymbol,
          enabled: enabled,
          marked: marked.contains(BookingPart.price),
          order: 4,
          translateError: l10n.bookingError,
          note: switch ((draft.totalPrice, nights)) {
            (final total?, final nights?) when nights > 1 =>
              l10n.bookingNightly(l10n.euros((total / nights).round())),
            _ => null,
          },
          onEdited: () => cubit.unmark(.price),
        ),
        FormTextField(
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
