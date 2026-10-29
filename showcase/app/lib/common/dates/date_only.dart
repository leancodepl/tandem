DateTime dateOnly(DateTime at) => DateTime(at.year, at.month, at.day);

/// The day [days] after the day of [at], at midnight; before it when
/// [days] is negative.
DateTime daysAfter(DateTime at, int days) =>
    DateTime(at.year, at.month, at.day + days);
