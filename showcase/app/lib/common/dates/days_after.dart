import 'package:waypoint_travel/waypoint_travel.dart';

/// The day [days] after the day of [at], at midnight; before it when
/// [days] is negative.
DateTime daysAfter(DateTime at, int days) =>
    addCalendarDays(calendarDay(at), days);
