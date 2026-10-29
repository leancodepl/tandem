import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_policy_breach_text.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The city, the dates and the route of the trip.
final class const TripHeader({super.key, required final bool wide})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final itinerary = context.select<TripCubit, Itinerary>(
      (trip) => trip.itinerary,
    );
    final info = context.select<TripCubit, Trip>((trip) => trip.info);
    final out = dateOnly(itinerary.outbound.departs);
    final home = dateOnly(itinerary.homebound.departs);
    final l10n = context.l10n;
    final dates = l10n.tripDates(
      l10n.dayRange(out, home),
      home.difference(out).inDays,
    );
    final display = wide ? AppText.display : AppText.headline;
    final route = _Route(itinerary.outbound.from, itinerary.outbound.to);

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          crossAxisAlignment: .end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 8,
                children: [
                  Text(info.city.toUpperCase(), style: display),
                  WaypointSwapText(dates, style: AppText.subtitle),
                ],
              ),
            ),
            if (wide) SizedBox(width: 280, child: route),
          ],
        ),
        if (!wide) ...[
          const SizedBox(height: 16),
          route,
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

final class const _Route(final String from, final String to)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(bottom: 8),
    child: Row(
      spacing: 12,
      children: [
        Text(from, style: AppText.route),
        const Expanded(child: WaypointDivider(color: Palette.lineStrong)),
        const RotatedBox(
          quarterTurns: 1,
          child: Icon(Icons.flight_rounded, size: 18, color: Palette.ink),
        ),
        const Expanded(child: WaypointDivider(color: Palette.lineStrong)),
        Text(to, style: AppText.route),
      ],
    ),
  );
}

/// What does not fit together on the trip, such as a night without a hotel.
final class const TripWarnings({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final warnings = context.select<TripCubit, List<TripWarning>>(
      (trip) => trip.warnings,
    );
    final l10n = context.l10n;
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .topLeft,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final warning in warnings)
            Padding(
              padding: const .only(top: 12),
              child: WaypointNote(
                Icons.warning_amber_rounded,
                l10n.warning(warning),
                tone: .warn,
              ),
            ),
        ],
      ),
    );
  }
}

/// The forwarded e-mails that change the trip and are not booked yet, so
/// the traveller sees why the assistant is at work.
final class const TripNews({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final id = context.select<TripCubit, String>((trip) => trip.info.id);
    final news = context.select<TripsCubit, List<ForwardedEmail>>(
      (trips) => trips.news(id),
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .topLeft,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final email in news)
            Padding(
              padding: const .only(top: 12),
              child: WaypointNote(
                Icons.mail_outline_rounded,
                context.l10n.tripInboxNews(email.from, email.subject),
                tone: .ai,
              ),
            ),
        ],
      ),
    );
  }
}

/// Back to where the trip was opened from, and what the trip is for. It
/// stays on top while the trip scrolls.
final class const TripTopBar({super.key, required final bool wide})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointTopBar(
    onBack: context.router.maybePop,
    trailing:
        context.select<TripCubit, String?>((trip) => trip.info.purpose) ??
        context.l10n.clientWork,
    wide: wide,
  );
}

/// The way to the arrival day, for a trip whose arrival Waypoint knows.
final class const ArrivalEntry({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trip = context.select<TripCubit, Trip>((trip) => trip.info);
    if (context.watch<ArrivalDays>().of(trip.id) == null) {
      return const SizedBox.shrink();
    }
    final lands = trip.booked.outbound.arrives;
    final l10n = context.l10n;
    return Padding(
      padding: const .only(top: 14),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: WaypointNote(
              Icons.flight_land_rounded,
              l10n.tripLands(l10n.day(lands), l10n.time(lands)),
            ),
          ),
          WaypointButton(
            l10n.arrivalDay,
            small: true,
            primary: false,
            onPressed: () =>
                context.router.navigate(ArrivalRoute(tripId: trip.id)),
          ),
        ],
      ),
    );
  }
}

extension on AppLocalizations {
  String warning(TripWarning warning) => switch (warning) {
    NoHotelForNight(:final night) => warningNoHotelForNight(day(night)),
    NoHotelBooked(:final nights) => warningNoHotelBooked(nights),
    BreaksPolicy(:final breach) => policyBreach(breach),
  };
}
