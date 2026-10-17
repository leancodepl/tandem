int toGrosze(double pln) => (pln * 100).round();

int withDiscount(int grosze, int percent) =>
    (grosze * (100 - percent) / 100).round();

String formatPln(int grosze) {
  final zloty = '${grosze ~/ 100}'.replaceAll(RegExp(r'\B(?=(\d{3})+$)'), ' ');
  final rest = '${grosze % 100}'.padLeft(2, '0');
  return '$zloty.$rest PLN';
}
