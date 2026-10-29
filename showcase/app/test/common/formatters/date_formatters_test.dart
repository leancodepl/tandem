import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:waypoint/common/formatters/date_formatters.dart';
import 'package:waypoint/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final friday = DateTime(2026, 10, 30, 18, 5);

  // The app's localizations delegates load them.
  setUpAll(() => initializeDateFormatting('en'));

  test('a time is in hours and minutes', () {
    expect(l10n.time(friday), '18:05');
  });

  test('a day has its weekday, and its time if asked', () {
    expect(l10n.day(friday), 'Fri 30 Oct');
    expect(l10n.dayTime(friday), 'Fri 30 Oct, 18:05');
  });

  test('a range of days names its month once when both are in it', () {
    expect(
      l10n.dayRange(DateTime(2026, 10, 28), friday),
      'Wed 28 – Fri 30 Oct',
    );
    expect(
      l10n.dayRange(DateTime(2026, 10, 31), DateTime(2026, 11, 2)),
      'Sat 31 Oct – Mon 2 Nov',
    );
  });
}
