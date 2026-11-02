import 'package:waypoint/features/trip/trip_item_id.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

sealed class const PlanItem() {
  TripItemId get id;

  DateTime get at;
}

final class const FlightItem(
  @override final TripItemId id,
  final Flight flight,
  final Flight booked,
) extends PlanItem {
  @override
  DateTime get at => flight.departs;
}

final class const HotelItem(final HotelStay hotel, final HotelStay? booked)
    extends PlanItem {
  @override
  TripItemId get id => .hotel;

  @override
  DateTime get at => hotel.checkIn;
}

final class const MeetingItem(final Meeting meeting, final Meeting? booked)
    extends PlanItem {
  @override
  TripItemId get id => .meeting(meeting.id);

  @override
  DateTime get at => meeting.start;
}

final class const NoHotelItem(@override final DateTime at) extends PlanItem {
  @override
  TripItemId get id => .hotel;
}

final class const DayPlan(
  final DateTime date,
  final List<PlanItem> items, {
  final DateTime? endDate,
});

List<DayPlan> planOf(Itinerary now, Itinerary booked) {
  final items = <PlanItem>[
    FlightItem(.outbound, now.outbound, booked.outbound),
    if (now.hotel case final hotel?)
      HotelItem(hotel, booked.hotel)
    else if (calendarDaysBetween(now.outbound.arrives, now.homebound.departs) >
        0)
      NoHotelItem(
        DateTime(
          now.outbound.arrives.year,
          now.outbound.arrives.month,
          now.outbound.arrives.day,
          15,
        ),
      ),
    for (final meeting in now.meetings)
      MeetingItem(meeting, booked.meeting(meeting.id)),
    FlightItem(.homebound, now.homebound, booked.homebound),
  ];
  final byDay = <DateTime, List<PlanItem>>{};
  for (final item in items) {
    byDay.putIfAbsent(_timelineDay(item.at), () => []).add(item);
  }
  final first = _timelineDay(now.outbound.departs);
  final last = _timelineDay(now.homebound.departs);
  final days = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final sections = <DayPlan>[];
  for (final (index, MapEntry(key: date, value: items)) in days.indexed) {
    sections.add(DayPlan(date, items..sort((a, b) => a.at.compareTo(b.at))));
    if (index + 1 == days.length) continue;
    final next = days[index + 1].key;
    final emptyDays = calendarDaysBetween(date, next) - 1;
    if (emptyDays > 0 &&
        calendarDaysBetween(first, date) >= 0 &&
        calendarDaysBetween(next, last) >= 0) {
      sections.add(
        DayPlan(
          addCalendarDays(date, 1),
          const [],
          endDate: emptyDays > 1 ? addCalendarDays(next, -1) : null,
        ),
      );
    }
  }
  return sections;
}

DateTime _timelineDay(DateTime at) => DateTime(at.year, at.month, at.day);
