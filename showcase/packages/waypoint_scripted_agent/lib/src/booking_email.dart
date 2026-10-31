final class const BookingEmail._({
  required final String confirmationNumber,
  final String? hotelName,
  final String? address,
  final DateTime? checkIn,
  final DateTime? checkOut,
  final int? wholeEuros,
}) {
  static BookingEmail? tryParse(String text) {
    final lines = text.split(RegExp(r'\r?\n'));

    String? field(String label) {
      final prefix = '$label:';
      for (final line in lines) {
        if (line.startsWith(prefix)) {
          final value = line.substring(prefix.length).trim();
          return value.isEmpty ? null : value;
        }
      }
      return null;
    }

    final confirmationNumber = field('Confirmation number');
    if (confirmationNumber == null) return null;
    final hotelName = switch (RegExp(r'^(.+?)\s*<')
        .firstMatch(field('From') ?? '')?[1]
        ?.trim()) {
      final name? when name.isNotEmpty => name,
      _ => null,
    };
    final signature = [
      for (final line in lines)
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final address =
        signature.length >= 2 &&
            hotelName != null &&
            signature[signature.length - 2] == hotelName
        ? signature.last
        : null;
    return BookingEmail._(
      confirmationNumber: confirmationNumber,
      hotelName: hotelName,
      address: address,
      checkIn: _checkIn(field('Check-in')),
      checkOut: _date(field('Check-out')),
      wholeEuros: _wholeEuros(field('Total')),
    );
  }

  static DateTime? _checkIn(String? text) {
    final day = _date(text);
    final time = RegExp(r', from (\d{2}):(\d{2})$').firstMatch(text ?? '');
    final hour = int.tryParse(time?[1] ?? '');
    final minute = int.tryParse(time?[2] ?? '');
    if (day == null || hour == null || minute == null) return null;
    if (hour > 23 || minute > 59) return null;
    final at = DateTime(day.year, day.month, day.day, hour, minute);
    return at.hour == hour && at.minute == minute ? at : null;
  }

  static DateTime? _date(String? text) {
    final match = RegExp(
      r'^(?:[A-Za-z]+, )?(\d{1,2}) ([A-Za-z]+) (\d{4})(?:, .*)?$',
    ).firstMatch(text ?? '');
    final day = int.tryParse(match?[1] ?? '');
    final month = _months[match?[2]?.toLowerCase()];
    final year = int.tryParse(match?[3] ?? '');
    if (day == null || month == null || year == null || year < 1) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static int? _wholeEuros(String? text) {
    final match = RegExp(r'^EUR (\d+)(?:\.00)?(?:, .*)?$')
        .firstMatch(text ?? '');
    final euros = int.tryParse(match?[1] ?? '');
    return euros != null && euros > 0 ? euros : null;
  }

  static const _months = {
    'january': 1,
    'february': 2,
    'march': 3,
    'april': 4,
    'may': 5,
    'june': 6,
    'july': 7,
    'august': 8,
    'september': 9,
    'october': 10,
    'november': 11,
    'december': 12,
  };
}
