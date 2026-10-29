import 'package:intl/intl.dart';
import 'package:waypoint/l10n/app_localizations.dart';

/// Dates and times as the screens show them, in the app's language.
extension DateFormatters on AppLocalizations {
  /// 18:05
  String time(DateTime at) => DateFormat.Hm(localeName).format(at);

  /// Fri 30 Oct
  String day(DateTime at) => DateFormat('E d MMM', localeName).format(at);

  /// Fri 30 Oct, 18:05
  String dayTime(DateTime at) =>
      DateFormat('E d MMM, HH:mm', localeName).format(at);

  /// Wed 28 – Fri 30 Oct, without the first month when both are in one.
  String dayRange(DateTime from, DateTime to) => dateRange(
    from.month == to.month
        ? DateFormat('E d', localeName).format(from)
        : day(from),
    day(to),
  );
}
