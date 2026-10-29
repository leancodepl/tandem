import 'package:equatable/equatable.dart';
import 'package:waypoint_travel/src/trip.dart';

/// An e-mail the traveller forwarded to Waypoint, with what it means for
/// one of their trips.
final class const ForwardedEmail({
  required final String from,
  required final String subject,
  required final DateTime received,
  required final String body,
  required final String tripId,
  required final EmailNews news,
}) with Equatable {
  @override
  List<Object?> get props => [from, subject, received, body, tripId, news];

  /// Whether the trip as booked already follows the e-mail. An invitation
  /// is done once its trip exists, so [booked] is null until then.
  bool isDoneIn(Itinerary? booked) => switch ((news, booked)) {
    (TripInvitation(), final booked) => booked != null,
    // An expense report, not the trip, settles a receipt.
    (Receipt(), _) => false,
    (_, null) => false,
    (MeetingMoved(:final meetingId, :final start), final booked?) =>
      booked.meeting(meetingId)?.start == start,
    (HotelConfirmation(:final number), final booked?) =>
      booked.hotel?.confirmation == number,
  };
}

/// What an e-mail changes for its trip.
sealed class const EmailNews() with Equatable;

/// A meeting of the trip moved.
final class const MeetingMoved({
  required final String meetingId,
  required final DateTime start,
}) extends EmailNews {
  @override
  List<Object?> get props => [meetingId, start];
}

/// An invitation to meetings that need a trip, which [ForwardedEmail.tripId]
/// names before it exists.
final class const TripInvitation({
  required final String city,
  required final String client,
}) extends EmailNews {
  @override
  List<Object?> get props => [city, client];
}

/// A receipt of the trip, for its expense report.
final class const Receipt({
  required final String id,
  required final String merchant,
  required final ExpenseCategory category,
  required final DateTime day,

  /// What the traveller paid, in whole euros.
  required final int paid,
}) extends EmailNews {
  @override
  List<Object?> get props => [id, merchant, category, day, paid];
}

enum ExpenseCategory() {
  taxi,
  meal,
  transport,
}

/// A hotel the traveller booked themselves, to add to the trip.
final class const HotelConfirmation(final String number) extends EmailNews {
  @override
  List<Object?> get props => [number];
}

/// What the traveller forwarded to Waypoint. A real app would fetch the
/// e-mails; the showcase keeps them here.
final class const Inbox() {
  /// Newest first.
  List<ForwardedEmail> get emails => _emails;

  /// The invitation that asks for the trip [tripId], or null.
  ForwardedEmail? invitation(String tripId) => _emails
      .where((email) => email.news is TripInvitation && email.tripId == tripId)
      .firstOrNull;
}

final _emails = [
  ForwardedEmail(
    from: 'Mira Novak, Alpenlicht',
    subject: 'Invitation: discovery workshop in Vienna',
    received: DateTime(2026, 10, 23, 16, 48),
    tripId: 'vienna',
    news: const TripInvitation(city: 'Vienna', client: 'Alpenlicht'),
    body: '''
From: Mira Novak <mira.novak@alpenlicht.example>
Subject: Invitation: discovery workshop in Vienna

Dear Ola,

we would love to start the redesign of our booking app with you. Could
you join us in Vienna for a discovery workshop?

Wednesday, 9 December 2026, 09:30 to 17:00: discovery workshop
Thursday, 10 December 2026, 09:00 to 12:00: roadmap session

Both at our office, Mariahilfer Str. 88, 1070 Vienna.

Looking forward to it,
Mira Novak
Head of Product, Alpenlicht''',
  ),
  ForwardedEmail(
    from: 'Jonas Weber, Studio Kraft',
    subject: 'Workshop moves to Friday',
    received: DateTime(2026, 10, 24, 9, 12),
    tripId: 'berlin',
    news: MeetingMoved(
      meetingId: 'workshop',
      start: DateTime(2026, 10, 30, 10),
    ),
    body: '''
From: Jonas Weber <jonas@studiokraft.example>
Subject: Workshop moves to Friday

Hi Ola,

our client review moved to Thursday, so we need to move the design
workshop to Friday, 30 October, same time: 10:00 to 16:00 at Köpenicker
Str. 70. The kickoff and the dinner on Wednesday stay as they are.

Sorry for the shuffle. See you on Wednesday!

Jonas''',
  ),
  ForwardedEmail(
    from: 'Havnegade Loft',
    subject: 'Your booking is confirmed: 55120873',
    received: DateTime(2026, 10, 22, 19, 30),
    tripId: 'copenhagen',
    news: const HotelConfirmation('55120873'),
    body: '''
From: Havnegade Loft <stay@havnegadeloft.example>
Subject: Your booking is confirmed: 55120873

Dear Ola Brandt,

thank you for booking with us. Your stay is confirmed.

Confirmation number: 55120873
Check-in: Wednesday, 18 November 2026, from 15:00
Check-out: Thursday, 19 November 2026, by 11:00
Room: Harbour Double, 1 night
Total: EUR 168.00, paid at the hotel

Velkommen to Copenhagen,
Havnegade Loft
Havnegade 44, 1058 Copenhagen''',
  ),
  ForwardedEmail(
    from: 'Spree Loft Hotel',
    subject: 'Your booking is confirmed: 84213907',
    received: DateTime(2026, 10, 20, 11, 5),
    tripId: 'berlin',
    news: const HotelConfirmation('84213907'),
    body: '''
From: Spree Loft Hotel <reservations@spreeloft.example>
Subject: Your booking is confirmed: 84213907

Dear Ola Brandt,

thank you for booking with us. Your stay is confirmed.

Confirmation number: 84213907
Check-in: Wednesday, 28 October 2026, from 15:00
Check-out: Thursday, 29 October 2026, by 11:00
Room: Loft Double, 1 night
Total: EUR 122.00, paid at the hotel

See you in Berlin,
Spree Loft Hotel
Am Wriezener Bahnhof 2, 10243 Berlin''',
  ),
  ForwardedEmail(
    from: 'G7 Taxi',
    subject: 'Your ride receipt: €58',
    received: DateTime(2026, 9, 15, 10, 41),
    tripId: 'paris',
    news: Receipt(
      id: 'R-0915-1',
      merchant: 'G7 Taxi',
      category: .taxi,
      day: DateTime(2026, 9, 15),
      paid: 58,
    ),
    body: '''
From: G7 Taxi <receipts@g7.example>
Subject: Your ride receipt: €58

Receipt R-0915-1
Ride on Tuesday, 15 September 2026, 10:05
Paris Charles de Gaulle to Quai de Valmy 88, Paris
Total: EUR 58.00, paid by card

Thank you,
G7 Taxi''',
  ),
  ForwardedEmail(
    from: 'Café Lumière',
    subject: 'Receipt: €18',
    received: DateTime(2026, 9, 15, 12, 52),
    tripId: 'paris',
    news: Receipt(
      id: 'R-0915-2',
      merchant: 'Café Lumière',
      category: .meal,
      day: DateTime(2026, 9, 15),
      paid: 18,
    ),
    body: '''
From: Café Lumière <hello@cafelumiere.example>
Subject: Receipt: €18

Receipt R-0915-2
Lunch on Tuesday, 15 September 2026, 12:20
1 menu du jour
Total: EUR 18.00, paid by card

Thank you,
Café Lumière''',
  ),
  ForwardedEmail(
    from: 'Bistrot du Canal',
    subject: 'Your receipt: €71',
    received: DateTime(2026, 9, 15, 21, 14),
    tripId: 'paris',
    news: Receipt(
      id: 'R-0915-3',
      merchant: 'Bistrot du Canal',
      category: .meal,
      day: DateTime(2026, 9, 15),
      paid: 71,
    ),
    body: '''
From: Bistrot du Canal <table@bistrotducanal.example>
Subject: Your receipt: €71

Receipt R-0915-3
Dinner on Tuesday, 15 September 2026, 20:40
Table for one, 2 courses and wine
Total: EUR 71.00, paid by card

Thank you,
Bistrot du Canal''',
  ),
  ForwardedEmail(
    from: 'RATP',
    subject: 'Your tickets: €12',
    received: DateTime(2026, 9, 16, 9, 20),
    tripId: 'paris',
    news: Receipt(
      id: 'R-0916-1',
      merchant: 'RATP',
      category: .transport,
      day: DateTime(2026, 9, 16),
      paid: 12,
    ),
    body: '''
From: RATP <tickets@ratp.example>
Subject: Your tickets: €12

Receipt R-0916-1
Bought on Wednesday, 16 September 2026, 09:10
10 metro tickets
Total: EUR 12.00, paid by card

Thank you,
RATP''',
  ),
];
