import 'package:equatable/equatable.dart';

final class const AirportCode._(final String value) with Equatable {
  factory(String text) =>
      tryParse(text) ??
      (throw FormatException('An airport code is three letters.', text));

  static final _format = RegExp(r'^[A-Z]{3}$');

  static AirportCode? tryParse(String text) {
    final value = text.trim().toUpperCase();
    return _format.hasMatch(value) ? AirportCode._(value) : null;
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
