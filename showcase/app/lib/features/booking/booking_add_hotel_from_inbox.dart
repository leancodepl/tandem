import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/features/booking/booking_sheet.dart';
import 'package:waypoint/features/trips/trips_cubit.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Booking');

/// Adds the hotel of [email] to [trip] with the booking form, then opens
/// the trip to show it there.
Future<void> addHotelFromInbox(
  BuildContext context,
  Trip trip,
  ForwardedEmail email,
) async {
  final trips = context.read<TripsCubit>();
  _log.info('Adding a hotel from the inbox to trip ${trip.id}');
  final stay = await showBookingSheet(
    context,
    connection: context.read<Agents>().booking,
    trip: trip,
    email: email,
  );
  if (stay == null || !context.mounted) {
    return;
  }

  trips.book(trip.id, trip.booked.copyWith(hotel: stay));
  _log.info('Added a hotel of ${stay.nights} nights to trip ${trip.id}');
  await context.router.navigate(TripRoute(tripId: trip.id));
}
