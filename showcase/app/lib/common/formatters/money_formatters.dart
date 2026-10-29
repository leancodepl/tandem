import 'package:intl/intl.dart';
import 'package:waypoint/l10n/app_localizations.dart';

/// Amounts in whole euros as the screens show them, in the app's language.
extension MoneyFormatters on AppLocalizations {
  /// €1,284
  String euros(int amount) => _euros.format(amount);

  /// €
  String get euroSymbol => _euros.currencySymbol;

  NumberFormat get _euros => NumberFormat.simpleCurrency(
    locale: localeName,
    name: 'EUR',
    decimalDigits: 0,
  );
}
