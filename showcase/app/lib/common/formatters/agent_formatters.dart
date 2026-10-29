// Dates in the English the agent reads. They stay the same in every locale
// of the app, so the model always reads one format.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// Fri 2026-10-30 18:05: the weekday with an exact date.
String forAgent(DateTime at, {bool withTime = true}) {
  final date = '${at.year}-${_two(at.month)}-${_two(at.day)}';
  final weekday = _weekdays[at.weekday - 1];
  return withTime ? '$weekday $date ${timeForAgent(at)}' : '$weekday $date';
}

/// 18:05
String timeForAgent(DateTime at) => '${_two(at.hour)}:${_two(at.minute)}';

/// Fri 30 Oct
String dayForAgent(DateTime at) =>
    '${_weekdays[at.weekday - 1]} ${at.day} ${_months[at.month - 1]}';

/// Wed 28 – Fri 30 Oct
String dayRangeForAgent(DateTime from, DateTime to) => from.month == to.month
    ? '${_weekdays[from.weekday - 1]} ${from.day} – ${dayForAgent(to)}'
    : '${dayForAgent(from)} – ${dayForAgent(to)}';
