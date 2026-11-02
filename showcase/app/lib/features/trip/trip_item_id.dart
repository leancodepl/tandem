import 'package:waypoint_travel/waypoint_travel.dart';

extension type const TripItemId._(String value) {
  factory meeting(MeetingId id) => TripItemId._('meeting:${id.value}');

  static const outbound = TripItemId._('outbound');
  static const homebound = TripItemId._('homebound');
  static const hotel = TripItemId._('hotel');
}
