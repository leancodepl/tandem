import 'package:waypoint/features/trip/trip_item_id.dart';

sealed class const MarksPresentationEvent();

final class const MarksPresentationEventItemChanged(final TripItemId id)
    extends MarksPresentationEvent;
