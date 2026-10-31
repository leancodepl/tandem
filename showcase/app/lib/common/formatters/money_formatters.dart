import 'package:intl/intl.dart';
import 'package:waypoint/l10n/app_localizations.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

extension MoneyFormatters on AppLocalizations {
  String money(Money value) =>
      _currency(value.currency).format(value.toDouble());

  String moneyDelta(Money value) {
    final format = _currency(value.currency);
    final amount = format.format(value.toDouble());
    return value.isNegative ? amount : '${format.symbols.PLUS_SIGN}$amount';
  }

  String currencySymbol(Currency currency) =>
      _currency(currency).currencySymbol;

  NumberFormat _currency(Currency currency) => NumberFormat.simpleCurrency(
    locale: localeName,
    name: currency.isoCode,
    decimalDigits: 0,
  );
}
