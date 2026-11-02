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
      calendarDaysBetween(out, home),
    );
    final display = wide ? WPTextStyle.display : WPTextStyle.headline;
    final route = _Route(
      itinerary.outbound.origin,
      itinerary.outbound.destination,
    );

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
                  WPSwapText(dates, style: WPTextStyle.subtitle),
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

final class const _Route(
  final AirportCode origin,
  final AirportCode destination,
) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .only(bottom: 8),
    child: OverflowBar(
      alignment: .spaceBetween,
      overflowAlignment: .center,
      overflowSpacing: 8,
      spacing: 12,
      children: [
        Text(origin.value, style: WPTextStyle.route),
        const SizedBox(
          width: 56,
          child: Row(
            spacing: 8,
            children: [
              Expanded(child: WPDivider(color: WPColors.lineStrong)),
              RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.flight_rounded,
                  size: 18,
                  color: WPColors.ink,
                ),
              ),
              Expanded(child: WPDivider(color: WPColors.lineStrong)),
            ],
          ),
        ),
        Text(destination.value, style: WPTextStyle.route),
      ],
    ),
  );
}

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
              child: WPNote(
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
    final id = context.select<TripCubit, TripId>((trip) => trip.info.id);
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
              child: WPNote(
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

final class const TripTopBar({super.key, required final bool wide})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WPTopBar(
    onBack: context.router.maybePop,
    trailing:
        context.select<TripCubit, String?>((trip) => trip.info.purpose) ??
        context.l10n.clientWork,
    wide: wide,
  );
}

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
      child: OverflowBar(
        alignment: .spaceBetween,
        overflowSpacing: 10,
        spacing: 10,
        children: [
          WPNote(
            Icons.flight_land_rounded,
            l10n.tripLands(l10n.day(lands), l10n.time(lands)),
          ),
          WPButton(
            l10n.arrivalDay,
            small: true,
            primary: false,
            onPressed: () =>
                context.router.navigate(ArrivalRoute(tripId: trip.id.value)),
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
