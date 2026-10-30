import 'package:flutter/widgets.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// A card with a title over its parts, such as what to do after landing.
final class const ArrivalCard({
  super.key,
  required final String title,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WaypointCard(
    border: Palette.aiLine,
    child: Column(
      crossAxisAlignment: .stretch,
      spacing: 14,
      children: [
        Text(title, style: AppText.title),
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const WaypointDivider(),
          child,
        ],
      ],
    ),
  );
}

/// Parts one below another, such as the ways from the airport.
final class const ArrivalColumn({
  super.key,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: .stretch, spacing: 10, children: children);
}

/// The next meeting: its title, where and when it starts.
final class const NextStop({
  super.key,
  required final String title,
  required final String place,
  required final DateTime start,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      Text(context.l10n.time(start), style: AppText.time),
      Expanded(
        child: Column(
          crossAxisAlignment: .start,
          spacing: 2,
          children: [
            Text(title, style: AppText.title),
            Text(place, style: AppText.label),
          ],
        ),
      ),
    ],
  );
}

/// One way from the airport: how, how long, the fare and when it arrives,
/// with a button to book it, or its booking once booked.
final class const RideOption({
  super.key,
  required final RideMode mode,
  required final int minutes,

  /// In whole euros.
  required final int fare,
  required final DateTime arrives,

  /// The booking's reference, once booked.
  final String? booked,

  /// Whether the company policy rules it out.
  final bool overPolicy = false,
  final VoidCallback? onBook,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 2,
      children: [
        WaypointTile(
          title: l10n.rideMode(mode.name),
          subtitle: l10n.rideLine(
            minutes,
            l10n.euros(fare),
            l10n.time(arrives),
          ),
          dimmed: overPolicy,
          trailing: booked == null && !overPolicy
              ? WaypointButton(l10n.book, small: true, onPressed: onBook)
              : null,
        ),
        switch ((booked, overPolicy)) {
          (final reference?, _) => WaypointNote(
            Icons.check_rounded,
            l10n.rideBooked(mode.name, reference),
            tone: .ai,
          ),
          (_, true) => WaypointNote(
            Icons.warning_amber_rounded,
            l10n.rideOverPolicy,
            tone: .warn,
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// The person who expects the traveller, with a button to text them when
/// the traveller arrives.
final class const HostNote({
  super.key,
  required final String name,
  required final bool told,
  final VoidCallback? onText,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WaypointTile(
      icon: Icons.person_outline_rounded,
      title: told ? l10n.hostTold(name) : l10n.hostExpects(name),
      trailing: told
          ? null
          : WaypointButton(
              l10n.textHost(name.split(' ').first),
              small: true,
              primary: false,
              onPressed: onText,
            ),
    );
  }
}

/// The hotel: when the room is ready, with a button to ask for it early.
final class const HotelNote({
  super.key,

  /// Null without a hotel booked.
  final String? name,
  final DateTime? checkIn,

  /// When the room is ready, once the traveller asked for it early.
  final DateTime? roomReady,
  final VoidCallback? onEarlyCheckIn,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WaypointTile(
      icon: Icons.hotel_outlined,
      title: name ?? l10n.noHotel,
      subtitle: switch ((roomReady, checkIn)) {
        (final ready?, _) => l10n.roomReadyAt(l10n.time(ready)),
        (_, final from?) => l10n.checkInFrom(l10n.time(from)),
        _ => l10n.noCheckIn,
      },
      trailing: roomReady == null
          ? WaypointButton(
              l10n.roomEarly,
              small: true,
              primary: false,
              onPressed: onEarlyCheckIn,
            )
          : null,
    );
  }
}
