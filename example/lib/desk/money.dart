const _groszePerZloty = 100;
const _wholePercent = 100;
const _currency = 'PLN';
const _thousands = ' ';

/// [pln] zloty in grosze, the unit the desk computes prices in.
int toGrosze(double pln) => (pln * _groszePerZloty).round();

/// [grosze] with [percent] off, rounded to the grosz.
int withDiscount(int grosze, int percent) =>
    (grosze * (_wholePercent - percent) / _wholePercent).round();

/// [grosze] as `1 099.12 PLN`.
String formatPln(int grosze) {
  final zloty = '${grosze ~/ _groszePerZloty}'.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => _thousands,
  );
  final rest = '${grosze % _groszePerZloty}'.padLeft(2, '0');
  return '$zloty.$rest $_currency';
}
