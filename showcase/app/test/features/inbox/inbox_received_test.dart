import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:waypoint/features/inbox/inbox_received.dart';
import 'package:waypoint/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  // The app's localizations delegates load them.
  setUpAll(() => initializeDateFormatting('en'));

  test('an e-mail came in at a time today, on a weekday, or on a day', () {
    final today = DateTime(2026, 10, 24);

    expect(
      [
        DateTime(2026, 10, 24, 9, 12),
        DateTime(2026, 10, 18, 9, 12),
        DateTime(2026, 10, 17, 9, 12),
      ].map((at) => l10n.received(at, today: today)),
      ['09:12', 'Sun', '17 Oct'],
    );
  });
}
