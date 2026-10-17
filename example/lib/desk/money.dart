/// [pln] zloty in grosze, the unit the desk computes prices in.
int toGrosze(double pln) => (pln * 100).round();

/// [grosze] with [percent] off, rounded to the grosz.
int withDiscount(int grosze, int percent) =>
    (grosze * (100 - percent) / 100).round();

/// [grosze] as `1 099.12 PLN`.
String formatPln(int grosze) {
  final zloty = '${grosze ~/ 100}'.replaceAll(RegExp(r'\B(?=(\d{3})+$)'), ' ');
  final rest = '${grosze % 100}'.padLeft(2, '0');
  return '$zloty.$rest PLN';
}
