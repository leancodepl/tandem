DateTime calendarDay(DateTime at) => at.isUtc
    ? DateTime.utc(at.year, at.month, at.day)
    : DateTime(at.year, at.month, at.day);

int calendarDaysBetween(DateTime start, DateTime end) {
  final first = DateTime.utc(start.year, start.month, start.day);
  final last = DateTime.utc(end.year, end.month, end.day);
  return last.difference(first).inDays;
}

DateTime addCalendarDays(DateTime at, int days) {
  final create = at.isUtc ? DateTime.utc : DateTime.new;
  return create(
    at.year,
    at.month,
    at.day + days,
    at.hour,
    at.minute,
    at.second,
    at.millisecond,
    at.microsecond,
  );
}
