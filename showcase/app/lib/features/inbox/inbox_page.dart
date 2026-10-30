import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:waypoint/features/expenses/expenses_reports_cubit.dart';
import 'package:waypoint/features/inbox/inbox_email_action.dart';
import 'package:waypoint/features/inbox/inbox_received.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The e-mails the traveller forwarded to Waypoint, each with its trip and
/// what is left to do about it.
@RoutePage()
final class const InboxPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripsCubit>();

    return WaypointTabPage(
      title: context.l10n.inboxTitle,
      above: context.l10n.inboxAbove,
      children: [
        for (final email in context.watch<Inbox>().emails)
          Padding(
            padding: const .only(bottom: 10),
            child: _EmailCard(email, trip: trips.tripOrNull(email.tripId)),
          ),
      ],
    );
  }
}

/// An e-mail: who sent it and what about, its text when opened, and what it
/// means for its trip.
final class const _EmailCard(
  final ForwardedEmail email, {
  required final Trip? trip,
}) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final open = useState(false);
    final done = switch (email.news) {
      Receipt(:final id) => context.select<ReportsCubit, bool>(
        (reports) => reports.report(email.tripId).claims(id),
      ),
      _ => email.isDoneIn(trip?.booked),
    };
    final (action, act) = emailAction(context, email, trip);
    final l10n = context.l10n;
    final city = trip?.city ?? '';

    return WaypointCard(
      onTap: () => open.value = !open.value,
      border: done ? Palette.line : Palette.aiLine,
      padding: const .fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 4,
        children: [
          Row(
            children: [
              Expanded(child: Text(email.from, style: AppText.title)),
              Text(
                l10n.received(
                  email.received,
                  today: context.watch<Traveller>().today,
                ),
                style: AppText.label,
              ),
            ],
          ),
          Text(email.subject, style: AppText.body),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: .topCenter,
            child: open.value
                ? Padding(
                    padding: const .symmetric(vertical: 10),
                    child: Text(
                      email.body,
                      style: AppText.label.copyWith(color: Palette.ink),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 6),
          if (done)
            WaypointNote(Icons.check_rounded, switch (email.news) {
              Receipt() => l10n.emailInReport(city),
              _ => l10n.emailOnTrip(city),
            }, maxLines: 1)
          else
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: WaypointNote(Icons.mail_outline_rounded, switch ((
                    email.news,
                    trip,
                  )) {
                    (TripInvitation(:final city), _) => l10n.emailToPlan(city),
                    (MeetingMoved(), final trip?) => l10n.emailChangesTrip(
                      trip.city,
                    ),
                    (_, final trip?) => l10n.emailNotOnTrip(trip.city),
                    _ => l10n.emailNoTrip,
                  }, tone: .ai),
                ),
                WaypointButton(action, small: true, onPressed: act),
              ],
            ),
        ],
      ),
    );
  }
}
