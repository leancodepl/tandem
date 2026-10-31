import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/common/formatters/money_formatters.dart';
import 'package:waypoint/l10n/app_localizations.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('euros are whole and grouped by thousands', () {
    expect([0, 1284, 1000000].map(wholeMoney).map(l10n.money), [
      '€0',
      '€1,284',
      '€1,000,000',
    ]);
  });

  test('the euro symbol is the one the amounts use', () {
    expect(l10n.currencySymbol(supportedCurrency), '€');
  });
}
