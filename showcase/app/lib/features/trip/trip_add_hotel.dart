import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:waypoint/agents.dart';
import 'package:waypoint/features/booking/booking_sheet.dart';
import 'package:waypoint/features/trip/trip_cubit.dart';
import 'package:waypoint/features/trip/trip_marks_cubit.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final _log = Logger('Trip');

/// Opens the booking form that a forwarded e-mail fills in, and adds the
/// hotel it gives to the trip on the screen.
Future<void> addHotelFromEmail(BuildContext context) async {
  final trip = context.read<TripCubit>();
  final marks = context.read<MarksCubit>();
  _log.info('Adding a hotel from an e-mail to trip ${trip.info.id}');
  final hotel = await showBookingSheet(
    context,
    connection: context.read<Agents>().booking,
    trip: trip.info.copyWith(booked: trip.state.booked),
  );
  if (hotel == null || trip.isClosed) {
    return;
  }

  trip.addHotel(hotel);
  _log.info('Added a hotel of ${hotel.nights} nights to trip ${trip.info.id}');
  // Filled in by the agent: marked until the traveller has seen it.
  marks.mark('hotel');
  await Future<void>.delayed(const Duration(seconds: 6));
  if (marks.isClosed) {
    return;
  }

  marks.unmark('hotel');
}
