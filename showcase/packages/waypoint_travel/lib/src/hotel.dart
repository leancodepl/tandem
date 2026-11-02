import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/value_objects.dart';

final class Hotel({
  required final HotelId id,
  required final String name,
  required final String city,
  required final String address,
  required final Money nightly,

  required final Duration walkDuration,
}) with Equatable {
  this {
    requireSupportedWholeMoney(nightly, 'nightly');
    if (nightly < wholeMoney(0)) {
      throw ArgumentError.value(nightly, 'nightly', 'Cannot be negative');
    }
    if (walkDuration >= Duration.zero) return;
    throw ArgumentError.value(
      walkDuration,
      'walkDuration',
      'Cannot be negative',
    );
  }

  @override
  List<Object?> get props => [id, name, city, address, nightly, walkDuration];
}
