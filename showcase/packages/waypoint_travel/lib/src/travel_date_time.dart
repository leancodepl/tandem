import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// This Central European demo uses Europe/Warsaw civil time. UTC values,
/// including parsed offsets, are instants; other values already hold travel
/// clock fields. Instants whose travel clock falls in the device's DST gap
/// are rejected. This does not validate raw local times in a DST gap.
DateTime travelDateTime(DateTime value) {
  if (value.isUtc) {
    final local = tz.TZDateTime.from(value, _travelLocation);
    final civil = DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    if (civil.year == local.year &&
        civil.month == local.month &&
        civil.day == local.day &&
        civil.hour == local.hour &&
        civil.minute == local.minute) {
      return civil;
    }
    throw ArgumentError.value(
      value,
      'value',
      'The device time zone skips this travel time during a daylight-saving change.',
    );
  }
  return value;
}

final _travelLocation = _loadTravelLocation();

tz.Location _loadTravelLocation() {
  tzdata.initializeTimeZones();
  return tz.getLocation('Europe/Warsaw');
}
