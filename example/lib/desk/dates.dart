const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// [date] as `23 Oct 2026`.
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
