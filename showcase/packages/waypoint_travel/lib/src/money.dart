import 'package:money2/money2.dart';

export 'package:money2/money2.dart' show Currency, Money;

final supportedCurrency = CommonCurrencies().euro;

Money wholeMoney(int wholeUnits) =>
    Money.fromNumWithCurrency(wholeUnits, supportedCurrency);

void requireSupportedWholeMoney(Money value, String field) {
  if (value.currency != supportedCurrency) {
    throw ArgumentError.value(
      value.currency.isoCode,
      field,
      'Must use ${supportedCurrency.isoCode}',
    );
  }
  if (value.decimalPart == BigInt.zero) return;
  throw ArgumentError.value(value, field, 'Must use whole currency units');
}
