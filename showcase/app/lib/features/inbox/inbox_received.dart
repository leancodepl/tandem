import 'package:intl/intl.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/l10n/app_localizations.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

extension InboxReceived on AppLocalizations {
  /// When an e-mail came in: its time today, its weekday this week, or its
  /// day.
  String received(DateTime at, {required DateTime today}) {
    final days = calendarDaysBetween(at, today);
    return switch (days) {
      0 => time(at),
      < 7 => DateFormat.E(localeName).format(at),
      _ => DateFormat('d MMM', localeName).format(at),
    };
  }
}
