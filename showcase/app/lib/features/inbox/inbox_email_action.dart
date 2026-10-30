import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:waypoint/features/booking/booking_add_hotel_from_inbox.dart';
import 'package:waypoint/l10n/l10n.dart';
import 'package:waypoint/navigation/app_router.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// What the traveller can do about [email], as a button's label and its
/// action, wherever the e-mail shows. [trip] is null for an invitation
/// whose trip is not planned yet.
(String, VoidCallback) emailAction(
  BuildContext context,
  ForwardedEmail email,
  Trip? trip,
) => switch ((email.news, trip)) {
  (TripInvitation(), _) => (
    context.l10n.planTheTrip,
    () =>
        context.router.navigate(PlanTripRoute(invitationTripId: email.tripId)),
  ),
  (_, null) => (
    context.l10n.planTheTrip,
    () => context.router.navigate(PlanTripRoute()),
  ),
  (MeetingMoved(), final trip?) => (
    context.l10n.reviewTheTrip,
    () => context.router.navigate(TripRoute(tripId: trip.id)),
  ),
  (HotelConfirmation(), final trip?) => (
    context.l10n.addToTrip,
    () => addHotelFromInbox(context, trip, email),
  ),
  (Receipt(), final trip?) => (
    context.l10n.openTheReport,
    () => context.router.push(ExpensesReportRoute(tripId: trip.id)),
  ),
};
