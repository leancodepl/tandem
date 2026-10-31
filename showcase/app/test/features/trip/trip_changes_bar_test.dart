import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/l10n/app_localizations.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  test('a difference in euros always has its sign', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect([174, 0, -20].map(wholeMoney).map(l10n.moneyDelta), [
      '+€174',
      '+€0',
      '-€20',
    ]);
  });
}
