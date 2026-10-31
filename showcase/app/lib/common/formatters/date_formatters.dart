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

  String dayRange(DateTime from, DateTime to) {
    final sameYear = from.year == to.year;
    final full = DateFormat(sameYear ? 'E d MMM' : 'E d MMM y', localeName);
    return dateRange(
      sameYear && from.month == to.month
          ? DateFormat('E d', localeName).format(from)
          : full.format(from),
      full.format(to),
    );
  }
}
