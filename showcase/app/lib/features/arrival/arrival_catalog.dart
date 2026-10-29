import 'package:tandem/tandem.dart';
import 'package:waypoint/features/arrival/arrival_widgets.dart';

part 'arrival_catalog.g.dart';

/// Start with one ArrivalCard titled for the day. Show the next meeting as a
/// NextStop, the ways from the airport as one RideOption per item of
/// /arrival/rides, the meeting's host as a HostNote and the hotel as a
/// HotelNote. Give a button its action only when its method is among your
/// tools; leave it out otherwise. Put first what the traveller needs first.
///
/// ```json
/// [
///   {"id": "root", "component": "ArrivalCard", "title": "After you land", "children": ["next", "rides", "host", "hotel"]},
///   {"id": "next", "component": "NextStop", "title": {"path": "/arrival/meeting/title"}, "place": {"path": "/arrival/meeting/place"}, "start": {"path": "/arrival/meeting/start"}},
///   {"id": "rides", "component": "ArrivalColumn", "children": {"componentId": "ride", "path": "/arrival/rides"}},
///   {"id": "ride", "component": "RideOption", "mode": {"path": "mode"}, "minutes": {"path": "minutes"}, "fare": {"path": "fare"}, "arrives": {"path": "arrives"},
///    "booked": {"path": "booked"}, "overPolicy": {"path": "overPolicy"},
///    "onBook": {"action": {"event": {"name": "book_ride", "context": {"rideId": {"path": "id"}}}}}},
///   {"id": "host", "component": "HostNote", "name": {"path": "/arrival/meeting/host"}, "told": {"path": "/arrival/meeting/hostTold"},
///    "onText": {"action": {"event": {"name": "message_host"}}}},
///   {"id": "hotel", "component": "HotelNote", "name": {"path": "/arrival/hotel/name"}, "checkIn": {"path": "/arrival/hotel/checkIn"}, "roomReady": {"path": "/arrival/hotel/roomReady"},
///    "onEarlyCheckIn": {"action": {"event": {"name": "request_early_check_in"}}}}
/// ]
/// ```
@TandemCatalog([
  ArrivalCard,
  ArrivalColumn,
  NextStop,
  RideOption,
  HostNote,
  HotelNote,
])
final class const ArrivalCatalog() with _$ArrivalCatalog;
