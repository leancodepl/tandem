import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/trip/trip_changes_bar.dart';
import 'package:waypoint/l10n/app_localizations.dart';

void main() {
  test('a difference in euros always has its sign', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect([174, 0, -20].map(l10n.eurosDelta), ['+€174', '+€0', '-€20']);
  });
}
