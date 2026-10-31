import 'package:equatable/equatable.dart';

final class NightCount(final int value) with Equatable {
  this {
    if (value < 1) {
      throw RangeError.range(value, 1, null, 'value');
    }
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => '$value';
}
