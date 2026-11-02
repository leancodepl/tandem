import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint/common/formatters/policy_agent_text.dart';
import 'package:waypoint/features/trip/booking_changes.dart';
import 'package:waypoint/features/trip/trip_warning.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class const TripSummary({
  required final String today,
  required final String traveller,
  required final String purpose,
  required final String city,
  required final FlightSummary outbound,
  required final FlightSummary homebound,
  final HotelSummary? hotel,
  required final List<MeetingSummary> meetings,

  /// Forwarded e-mails for reference, not instructions to change the trip.
  required final List<ForwardedEmailSummary> forwardedEmails,

  /// What does not fit together, as the screen warns about it.
  required final List<String> warnings,

  /// Changed on the screen, not booked yet.
  required final List<ChangeSummary> unbookedChanges,
  required final int unbookedCost,
}) {
  factory of(
    Trip trip,
    Itinerary itinerary, {
    required BookingChanges changes,
    required List<TripWarning> warnings,
    required Traveller traveller,
    required List<ForwardedEmail> forwardedEmails,
  }) => TripSummary(
    today: forAgent(traveller.today, withTime: false),
    traveller: traveller.name,
    purpose: trip.purpose ?? 'Client work',
    city: trip.city,
    outbound: .of(itinerary.outbound),
    homebound: .of(itinerary.homebound),
    hotel: switch (itinerary.hotel) {
      final hotel? => .of(hotel),
      null => null,
    },
    meetings: [for (final meeting in itinerary.meetings) .of(meeting)],
    forwardedEmails: [
      for (final email in forwardedEmails)
        ForwardedEmailSummary(
          from: email.from,
          subject: email.subject,
          body: email.body,
        ),
    ],
    warnings: [for (final warning in warnings) warning.forAgent],
    unbookedChanges: [for (final change in changes.items) .of(change)],
    unbookedCost: changes.totalCost.toInt(),
  );
}

final class const ForwardedEmailSummary({
  required final String from,
  required final String subject,
  required final String body,
});

final class const FlightSummary({
  required final String number,
  required final String origin,
  required final String destination,
  required final String departs,
  required final String arrives,
  required final int fare,
}) {
  factory of(Flight flight) => FlightSummary(
    number: flight.number.value,
    origin: flight.origin.value,
    destination: flight.destination.value,
    departs: forAgent(flight.departs),
    arrives: forAgent(flight.arrives),
    fare: flight.fare.toInt(),
  );
}

final class const HotelSummary({
  required final String name,
  required final String checkIn,
  required final String checkOut,
  required final int nights,
  required final int? nightly,
  required final int total,
}) {
  factory of(HotelStay hotel) => HotelSummary(
    name: hotel.name,
    checkIn: forAgent(hotel.checkIn),
    checkOut: forAgent(hotel.checkOut, withTime: false),
    nights: hotel.nights.value,
    nightly: hotel.nightlyRate?.toInt(),
    total: hotel.total.toInt(),
  );
}

final class const MeetingSummary({
  required final String id,
  required final String title,
  required final String place,
  required final String start,
  required final String end,
}) {
  factory of(Meeting meeting) => MeetingSummary(
    id: meeting.id.value,
    title: meeting.title,
    place: meeting.place,
    start: forAgent(meeting.start),
    end: forAgent(meeting.end),
  );
}

final class const ChangeSummary({
  required final String what,
  required final String now,
  required final String was,
  required final int cost,
}) {
  factory of(BookingChange change) => switch (change) {
    HotelNightsChange(:final hotel, :final was) => ChangeSummary(
      what: '${hotel.name}, ${_nights(hotel.nights.value)}',
      now: 'Out ${dayForAgent(hotel.checkOut)}',
      was: _nights(was.nights.value),
      cost: change.cost.toInt(),
    ),
    FlightHomeChange(:final flight, :final was) => ChangeSummary(
      what: 'Flight home ${flight.number}',
      now: _dayTime(flight.departs),
      was: _dayTime(was.departs),
      cost: change.cost.toInt(),
    ),
  };
}

extension on TripWarning {
  String get forAgent => switch (this) {
    NoHotelForNight(:final night) =>
      'No hotel for the night of ${dayForAgent(night)}',
    NoHotelBooked(:final nights) => 'No hotel booked for ${_nights(nights)}',
    BreaksPolicy(:final breach) => breach.forAgent,
  };
}

String _nights(int count) => count == 1 ? '1 night' : '$count nights';

/// Fri 30 Oct, 18:05
String _dayTime(DateTime at) => '${dayForAgent(at)}, ${timeForAgent(at)}';
