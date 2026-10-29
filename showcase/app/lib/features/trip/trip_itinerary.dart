import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/features/trip/trip_add_hotel.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_item_keys.dart';
import 'package:waypoint/features/trip/trip_marks_cubit.dart';
import 'package:waypoint/features/trip/trip_policy_breach_text.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint_design_system/waypoint_design_system.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// One thing on the trip's timeline.
sealed class const PlanItem() {
  String get id;

  DateTime get at;
}

final class const FlightItem(
  @override final String id,
  final Flight flight,
  final Flight booked,
) extends PlanItem {
  @override
  DateTime get at => flight.departs;
}

final class const HotelItem(final HotelStay hotel, final HotelStay? booked)
    extends PlanItem {
  @override
  String get id => 'hotel';

  @override
  DateTime get at => hotel.checkIn;
}

final class const MeetingItem(final Meeting meeting, final Meeting? booked)
    extends PlanItem {
  @override
  String get id => meeting.id;

  @override
  DateTime get at => meeting.start;
}

/// Where the hotel goes while the trip has none.
final class const NoHotelItem(@override final DateTime at) extends PlanItem {
  @override
  String get id => 'hotel';
}

final class const DayPlan(final DateTime date, final List<PlanItem> items);

List<DayPlan> planOf(Itinerary now, Itinerary booked) {
  final items = <PlanItem>[
    FlightItem('outbound', now.outbound, booked.outbound),
    if (now.hotel case final hotel?)
      HotelItem(hotel, booked.hotel)
    else if (dateOnly(now.homebound.departs)
        .isAfter(dateOnly(now.outbound.departs)))
      NoHotelItem(
        dateOnly(now.outbound.departs).add(const Duration(hours: 15)),
      ),
    for (final meeting in now.meetings)
      MeetingItem(meeting, booked.meeting(meeting.id)),
    FlightItem('homebound', now.homebound, booked.homebound),
  ];
  final first = dateOnly(now.outbound.departs);
  final last = dateOnly(now.homebound.departs);
  return [
    for (
      var date = first;
      !date.isAfter(last);
      date = DateTime(date.year, date.month, date.day + 1)
    )
      DayPlan(
        date,
        [
          for (final item in items)
            if (dateOnly(item.at) == date) item,
        ]..sort((a, b) => a.at.compareTo(b.at)),
      ),
  ];
}

/// The trip's days: columns side by side when [wide], sections on a phone.
/// A card that moves to another day glides there.
final class const ItineraryView({super.key, required final bool wide})
    extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<TripCubit>().state;
    final days = planOf(state.current, state.booked);
    final ids = {for (final day in days) ...day.items.map((item) => item.id)};
    final dates = {for (final day in days) day.date};
    final newItems = switch (usePrevious(ids)) {
      final shown? => ids.difference(shown),
      null => const <String>{},
    };
    final newDays = switch (usePrevious(dates)) {
      final shown? => dates.difference(shown),
      null => const <DateTime>{},
    };

    Widget column(DayPlan day) => _Day(day, newItems: newItems, wide: wide);

    if (!wide) {
      return Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final day in days)
            Appear(
              key: ValueKey(day.date),
              enabled: newDays.contains(day.date),
              child: column(day),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / days.length;
        return Row(
          crossAxisAlignment: .start,
          children: [
            for (final (index, day) in days.indexed)
              _AnimatedColumn(
                key: ValueKey(day.date),
                width: width,
                animateIn: newDays.contains(day.date),
                child: WaypointDividedColumn(
                  first: index == 0,
                  child: Padding(
                    padding: .only(
                      left: index == 0 ? 0 : 18,
                      right: index == days.length - 1 ? 0 : 18,
                    ),
                    child: column(day),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A day's column whose width follows [width], growing from nothing when
/// the day is new. Its content takes the final width at once, so text
/// does not reflow while it moves.
final class const _AnimatedColumn({
  super.key,
  required final double width,
  required final bool animateIn,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: animateIn ? 0 : width, end: width),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeInOutCubic,
    builder: (context, value, child) => SizedBox(
      width: value,
      child: ClipRect(
        child: OverflowBox(
          alignment: .topLeft,
          minWidth: width,
          maxWidth: width,
          fit: .deferToChild,
          child: child,
        ),
      ),
    ),
    child: child,
  );
}

final class const _Day(
  final DayPlan day, {
  required final Set<String> newItems,
  required final bool wide,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final keys = context.watch<ItemKeys>();
    final l10n = context.l10n;
    return Padding(
      padding: .only(top: 16, bottom: wide ? 0 : 8),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 10,
        children: [
          Text(l10n.day(day.date).toUpperCase(), style: AppText.day),
          if (day.items.isEmpty)
            Padding(
              padding: const .symmetric(vertical: 8),
              child: Text(l10n.nothingPlanned, style: AppText.label),
            ),
          for (final (index, item) in day.items.indexed)
            Flip(
              key: keys[item.id],
              slot: (day.date, index),
              child: Appear(
                enabled: newItems.contains(item.id),
                child: switch (item) {
                  FlightItem(id: 'homebound') => _HomeboundCard(item),
                  final FlightItem flight => _FlightCard(flight),
                  final HotelItem hotel => _HotelCard(hotel),
                  final MeetingItem meeting => _MeetingCard(meeting),
                  NoHotelItem() => const _NoHotelCard(),
                },
              ),
            ),
        ],
      ),
    );
  }
}

final class const _FlightCard(final FlightItem item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      _Card(id: item.id, child: _FlightBody(item));
}

final class const _FlightBody(final FlightItem item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final FlightItem(:flight, :booked) = item;
    final changed = !flight.isSameAs(booked);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .start,
      children: [
        _CardHead(
          l10n.flightNumber(flight.number),
          trailing: item.id == 'outbound' ? l10n.flightOut : l10n.flightHome,
        ),
        const SizedBox(height: 4),
        WaypointSwapText(
          l10n.flightTimes(
            l10n.time(flight.departs),
            l10n.time(flight.arrives),
          ),
          style: AppText.time,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.flightRoute(
            FlightSearch.airport(flight.from),
            FlightSearch.airport(flight.to),
          ),
          style: AppText.label,
        ),
        _Was(changed ? l10n.dayTime(booked.departs) : null),
      ],
    );
  }
}

/// The flight home: a tap opens the day's other flights, as the agent's
/// [TripCubit.findFlights] gives them.
final class const _HomeboundCard(final FlightItem item) extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final open = useState(false);
    // The options can change between showing and the tap, such as when the
    // agent moves a meeting.
    final refused = useState<PolicyBreach?>(null);
    final options = context.select<TripCubit, List<(Flight, PolicyBreach?)>>(
      (trip) => trip.homeboundOptions,
    );

    void pick(Flight flight) {
      refused.value = context.read<TripCubit>().changeHomeboundFlight(flight);
      if (refused.value != null) return;

      context.read<MarksCubit>().unmark('homebound');
      Future<void>.delayed(const Duration(milliseconds: 380), () {
        if (context.mounted) {
          open.value = false;
        }
      });
    }

    void toggle() {
      open.value = !open.value;
      refused.value = null;
      if (open.value) {
        // Once the options are open, so that all of them show.
        Future<void>.delayed(const Duration(milliseconds: 340), () {
          if (context.mounted) {
            Scrollable.ensureVisible(
              context,
              alignmentPolicy: .keepVisibleAtEnd,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      }
    }

    return _Card(
      id: item.id,
      onTap: toggle,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          _FlightBody(item),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: .topCenter,
            child: open.value
                ? Padding(
                    padding: const .only(top: 12),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        _FlightPicker(
                          options,
                          selected: item.flight,
                          onPick: pick,
                        ),
                        if (refused.value case final breach?)
                          InlineError(context.l10n.policyBreach(breach)),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

final class const _FlightPicker(
  final List<(Flight, PolicyBreach?)> options, {
  required final Flight selected,
  required final ValueChanged<Flight> onPick,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WaypointGroup(
      color: null,
      border: Palette.lineStrong,
      children: [
        for (final (flight, breach) in options)
          WaypointOption(
            lead: l10n.time(flight.departs),
            label: breach == null ? flight.number : l10n.tooEarly,
            trailing: l10n.euros(flight.fare),
            selected: flight.isSameAs(selected),
            onTap: breach == null ? () => onPick(flight) : null,
          ),
      ],
    );
  }
}

final class const _HotelCard(final HotelItem item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final HotelItem(:hotel, :booked) = item;
    final changed = booked != null && booked.nights != hotel.nights;
    final l10n = context.l10n;
    return _Card(
      id: item.id,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _CardHead(l10n.hotel, trailing: l10n.nights(hotel.nights)),
          const SizedBox(height: 4),
          Text(hotel.name, style: AppText.title),
          const SizedBox(height: 2),
          WaypointSwapText(
            l10n.hotelTimes(l10n.time(hotel.checkIn), l10n.day(hotel.checkOut)),
            style: AppText.label,
          ),
          _Was(changed ? l10n.nights(booked.nights) : null),
        ],
      ),
    );
  }
}

/// The way to add a hotel the traveller booked themselves.
final class const _NoHotelCard() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WaypointCard(
      color: null,
      border: Palette.lineStrong,
      padding: const .fromLTRB(16, 12, 14, 14),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _CardHead(l10n.hotel),
          const SizedBox(height: 4),
          Text(l10n.noHotelYet, style: AppText.title),
          const SizedBox(height: 2),
          Text(l10n.noHotelText, style: AppText.label),
          const SizedBox(height: 12),
          WaypointButton(
            l10n.addFromEmail,
            small: true,
            primary: false,
            icon: Icons.mail_outline_rounded,
            onPressed: () => addHotelFromEmail(context),
          ),
        ],
      ),
    );
  }
}

final class const _MeetingCard(final MeetingItem item) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final MeetingItem(:meeting, :booked) = item;
    final moved = booked != null && booked.start != meeting.start;
    final l10n = context.l10n;
    return _Card(
      id: item.id,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _CardHead(l10n.meeting),
          const SizedBox(height: 4),
          Text(meeting.title, style: AppText.title),
          const SizedBox(height: 2),
          WaypointSwapText(
            l10n.meetingTimes(
              l10n.time(meeting.start),
              l10n.time(meeting.end),
              meeting.place.split(',').first,
            ),
            style: AppText.label,
          ),
          _Was(moved ? l10n.dayTime(booked.start) : null),
        ],
      ),
    );
  }
}

/// A card of the timeline, marked in blue while the assistant's change of it
/// stands.
final class const _Card({
  required final String id,
  required final Widget child,
  final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final marked = context.select<MarksCubit, bool>(
      (marks) => marks.state.ids.contains(id),
    );
    return WaypointCard(
      onTap: onTap,
      marked: marked,
      padding: const .fromLTRB(16, 12, 14, 14),
      child: child,
    );
  }
}

final class const _CardHead(final String label, {final String? trailing})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppText.label)),
      if (trailing case final text?)
        WaypointSwapText(text, style: AppText.label),
    ],
  );
}

/// What a booking was before its change, struck through.
final class const _Was(final String? was) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    alignment: .topLeft,
    child: switch (was) {
      final text? => Padding(
        padding: const .only(top: 6),
        child: Text(
          context.l10n.was(text),
          style: AppText.label.merge(AppText.struck),
        ),
      ),
      null => const SizedBox(width: double.infinity),
    },
  );
}
