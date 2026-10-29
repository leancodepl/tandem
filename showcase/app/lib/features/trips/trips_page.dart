import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/features/inbox/inbox_email_action.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The traveller's trips, with what in their inbox changes one of them.
@RoutePage()
final class const TripsPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripsCubit>();
    final news = <(Trip?, ForwardedEmail)>[
      for (final email in trips.invitations) (null, email),
      for (final trip in trips.state.trips)
        for (final email in trips.news(trip.id)) (trip, email),
    ];
    final traveller = context.watch<Traveller>();
    final l10n = context.l10n;

    return WaypointTabPage(
      title: l10n.tripsTitle,
      above: l10n.tripsGreeting(traveller.name.split(' ').first),
      trailing: WaypointButton(
        l10n.planATrip,
        small: true,
        primary: false,
        icon: Icons.add_rounded,
        onPressed: () => context.router.navigate(PlanTripRoute()),
      ),
      children: [
        if (news.isNotEmpty) ...[
          Text(l10n.tripsNeedsYou, style: AppText.day),
          const SizedBox(height: 10),
          for (final (trip, email) in news)
            Padding(
              padding: const .only(bottom: 10),
              child: _NewsCard(trip, email),
            ),
          const SizedBox(height: 20),
        ],
        Text(l10n.tripsUpcoming, style: AppText.day),
        const SizedBox(height: 10),
        for (final trip in trips.state.trips)
          if (!trip.isPastOn(traveller.today))
            Padding(
              padding: const .only(bottom: 12),
              child: _TripCard(
                trip,
                onTap: () =>
                    context.router.navigate(TripRoute(tripId: trip.id)),
              ),
            ),
        const SizedBox(height: 20),
        Text(l10n.tripsPast, style: AppText.day),
        const SizedBox(height: 10),
        for (final trip in trips.state.trips)
          if (trip.isPastOn(traveller.today))
            Padding(
              padding: const .only(bottom: 12),
              // After a trip, what is left to do is its expenses.
              child: _TripCard(
                trip,
                onTap: () =>
                    context.router.push(ExpensesReportRoute(tripId: trip.id)),
              ),
            ),
      ],
    );
  }
}

/// An e-mail that changes a trip or asks for a new one, with the way to act
/// on it.
final class const _NewsCard(final Trip? trip, final ForwardedEmail email)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, text) = switch ((email.news, trip)) {
      (TripInvitation(:final city, :final client), _) => (
        l10n.invitationTitle(city, client),
        l10n.invitationText(email.from, city),
      ),
      (MeetingMoved(:final meetingId, :final start), final trip?) => (
        l10n.meetingMovedTitle(trip.city, email.subject),
        l10n.meetingMovedText(
          email.from,
          trip.booked.meeting(meetingId)?.title.toLowerCase() ??
              l10n.meetingFallback,
          l10n.dayTime(start),
        ),
      ),
      (HotelConfirmation(), final trip?) => (
        l10n.hotelToAddTitle(trip.city),
        l10n.hotelToAddText(email.from),
      ),
      _ => (email.subject, email.from),
    };
    final (action, act) = emailAction(context, email, trip);

    return WaypointCard(
      border: Palette.aiLine,
      child: Column(
        crossAxisAlignment: .start,
        spacing: 6,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: Palette.aiText,
              ),
              Expanded(child: Text(title, style: AppText.title)),
            ],
          ),
          Text(text, style: AppText.label),
          const SizedBox(height: 6),
          WaypointButton(action, small: true, onPressed: act),
        ],
      ),
    );
  }
}

/// A trip in the list: where, when, why and what is booked.
final class const _TripCard(
  final Trip trip, {
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Trip(:city, :purpose, :booked) = trip;
    final out = dateOnly(booked.outbound.departs);
    final home = dateOnly(booked.homebound.departs);
    final l10n = context.l10n;

    return WaypointListCard(
      onTap: onTap,
      title: city.toUpperCase(),
      subtitle: l10n.tripDates(
        l10n.dayRange(out, home),
        home.difference(out).inDays,
      ),
      caption: purpose ?? l10n.clientWork,
      footer: [
        WaypointNote(
          Icons.flight_rounded,
          l10n.flightAt(
            booked.outbound.number,
            l10n.time(booked.outbound.departs),
          ),
          maxLines: 1,
        ),
        switch (booked.hotel) {
          final hotel? => WaypointNote(
            Icons.hotel_rounded,
            hotel.name,
            maxLines: 1,
          ),
          null => WaypointNote(
            Icons.hotel_outlined,
            l10n.noHotelYet,
            tone: .warn,
          ),
        },
      ],
    );
  }
}
