import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint_travel/demo.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  final berlin = demoTrips()
      .singleWhere((trip) => trip.id == TripId('berlin'))
      .booked;

  ForwardedEmail email(EmailNews news) => ForwardedEmail(
    from: 'Studio Kraft',
    subject: 'News',
    received: DateTime(2026, 10, 24),
    body: '',
    tripId: TripId('berlin'),
    news: news,
  );

  test('an invitation is done once its trip exists', () {
    final invitation = email(
      const TripInvitation(city: 'Berlin', client: 'Studio Kraft'),
    );

    expect(invitation.isDoneIn(null), isFalse);
    expect(invitation.isDoneIn(berlin), isTrue);
  });

  test('a moved meeting is done once the trip has it at its new time', () {
    final friday = DateTime(2026, 10, 30, 10);
    final moved = email(
      MeetingMoved(meetingId: MeetingId('workshop'), start: friday),
    );
    final followed = berlin.copyWith(
      meetings: [
        for (final meeting in berlin.meetings)
          if (meeting.id == MeetingId('workshop'))
            meeting.movedTo(friday.toUtc())
          else
            meeting,
      ],
    );

    expect(moved.isDoneIn(berlin), isFalse);
    expect(moved.isDoneIn(followed), isTrue);
  });

  test('a hotel confirmation is done once the trip has its number', () {
    expect(
      email(HotelConfirmation(BookingReference('84213907'))).isDoneIn(berlin),
      isTrue,
    );
    expect(
      email(HotelConfirmation(BookingReference('55120873'))).isDoneIn(berlin),
      isFalse,
    );
  });

  test('a receipt is never done in the trip: the expense report takes it', () {
    final receipt = email(
      Receipt(
        id: ReceiptId('R-1028-1'),
        merchant: 'Café Ostkreuz',
        category: .meal,
        day: DateTime(2026, 10, 28),
        paid: wholeMoney(38),
      ),
    );

    expect(receipt.isDoneIn(berlin), isFalse);
  });

  test('reading an inbox cannot mutate its shared messages', () {
    expect(() => const Inbox().emails.clear(), throwsUnsupportedError);
  });
}
