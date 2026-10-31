import 'package:equatable/equatable.dart';

final class const FlightNumber._(final String value) with Equatable {
  factory(String text) =>
      tryParse(text) ??
      (throw FormatException(
        'Use a two-character airline code and one to four flight digits, '
        'optionally followed by a letter.',
        text,
      ));

  static final _format = RegExp(r'^([A-Z0-9]{2})\s*([0-9]{1,4}[A-Z]?)$');

  static FlightNumber? tryParse(String text) {
    final match = _format.firstMatch(text.trim().toUpperCase());
    if (match == null) return null;
    return switch ((match.group(1), match.group(2))) {
      (final airline?, final flight?) => FlightNumber._('$airline $flight'),
      _ => null,
    };
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
