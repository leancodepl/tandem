import 'package:equatable/equatable.dart';

/// Who uses Waypoint, and the day it is for them.
final class const Traveller({
  required final String name,
  required final DateTime today,
}) with Equatable {
  @override
  List<Object?> get props => [name, today];
}
