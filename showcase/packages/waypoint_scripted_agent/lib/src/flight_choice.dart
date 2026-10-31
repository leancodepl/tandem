final class const FlightChoice._({
  required final String number,
  required final DateTime departs,
}) {
  static Iterable<FlightChoice> allowed(List<Object?> options) sync* {
    for (final option in options) {
      if (option case {
        'number': final String number,
        'departs': final String departure,
        'unavailable': null,
      }) {
        if (_departure(departure) case final departs?) {
          yield FlightChoice._(number: number, departs: departs);
        }
      }
    }
  }

  String get dateArgument => departs.toIso8601String().split('T').first;

  static DateTime? _departure(String text) {
    if (text.split(' ') case [_, final date, final time]) {
      final departs = DateTime.tryParse('$date $time');
      if (departs != null &&
          departs.toIso8601String() == '${date}T$time:00.000') {
        return departs;
      }
    }
    return null;
  }
}
