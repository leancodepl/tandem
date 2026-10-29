// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Waypoint';

  @override
  String dateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String nights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$_temp0';
  }

  @override
  String tripDates(String dates, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$dates · $_temp0';
  }

  @override
  String get clientWork => 'Client work';

  @override
  String stillMissing(String items) {
    return 'Still missing: $items.';
  }

  @override
  String get listSeparator => ', ';

  @override
  String companyPolicy(String rules) {
    return 'Company policy: $rules';
  }

  @override
  String tripPolicy(String maxNightly, String morningUntil) {
    return 'Economy flights. Hotels up to $maxNightly a night. Arrive the evening before a meeting that starts before $morningUntil. Fly home at least an hour after the last meeting ends.';
  }

  @override
  String expensesPolicy(String mealsPerDay) {
    return 'Meals are paid back up to $mealsPerDay a day. Taxis and public transport are paid back in full. Every expense needs its receipt.';
  }

  @override
  String get agentUnreachable =>
      'Waypoint cannot reach the assistant. Check your connection.';

  @override
  String get agentRunFailed => 'The assistant ran into a problem.';

  @override
  String get approvalFallback => 'The assistant asks to go ahead.';

  @override
  String get booking => 'Booking';

  @override
  String get addToTrip => 'Add to trip';

  @override
  String get adding => 'Adding';

  @override
  String get noHotelYet => 'No hotel yet';

  @override
  String flightAt(String number, String time) {
    return '$number · $time';
  }

  @override
  String flightRoute(String from, String to) {
    return '$from → $to';
  }

  @override
  String meetingTimes(String start, String end, String place) {
    return '$start–$end · $place';
  }

  @override
  String get tabTrips => 'Trips';

  @override
  String get tabInbox => 'Inbox';

  @override
  String get tabExpenses => 'Expenses';

  @override
  String get tripsTitle => 'TRIPS';

  @override
  String tripsGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get planATrip => 'Plan a trip';

  @override
  String get tripsNeedsYou => 'NEEDS YOU';

  @override
  String get tripsUpcoming => 'UPCOMING';

  @override
  String get tripsPast => 'PAST';

  @override
  String invitationTitle(String city, String client) {
    return '$city · Invitation from $client';
  }

  @override
  String invitationText(String from, String city) {
    return '$from invites you to $city. Waypoint plans the trip within your company policy.';
  }

  @override
  String meetingMovedTitle(String city, String subject) {
    return '$city · $subject';
  }

  @override
  String meetingMovedText(String from, String meeting, String when) {
    return '$from moved the $meeting to $when. Your flight home and hotel are booked for the old day.';
  }

  @override
  String get meetingFallback => 'meeting';

  @override
  String hotelToAddTitle(String city) {
    return '$city · A hotel to add';
  }

  @override
  String hotelToAddText(String from) {
    return '$from confirmed your stay. It is not on the trip yet.';
  }

  @override
  String get unknownTrip => 'This trip is not in Waypoint.';

  @override
  String get yourTrips => 'Your trips';

  @override
  String get unknownInvitation => 'This invitation is not in your inbox.';

  @override
  String get inboxTitle => 'INBOX';

  @override
  String get inboxAbove => 'Forwarded to Waypoint';

  @override
  String emailInReport(String city) {
    return 'In your $city expense report';
  }

  @override
  String emailOnTrip(String city) {
    return 'On your $city trip';
  }

  @override
  String emailToPlan(String city) {
    return 'A trip to $city to plan';
  }

  @override
  String emailChangesTrip(String city) {
    return 'Changes your $city trip';
  }

  @override
  String emailNotOnTrip(String city) {
    return 'Not on your $city trip yet';
  }

  @override
  String get emailNoTrip => 'For a trip not planned yet';

  @override
  String get planTheTrip => 'Plan the trip';

  @override
  String get reviewTheTrip => 'Review the trip';

  @override
  String get openTheReport => 'Open the report';

  @override
  String get expensesTitle => 'EXPENSES';

  @override
  String get expensesAbove => 'After your trips';

  @override
  String get expensesNone =>
      'Your trips are still ahead. Forward their receipts to Waypoint, and the report waits here when you are back.';

  @override
  String reportSubmittedLine(String total, String confirmation) {
    return 'Submitted · $total · $confirmation';
  }

  @override
  String reportToSubmit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts',
      one: '1 receipt',
    );
    return 'To submit · $_temp0';
  }

  @override
  String get reportAdding => 'Adding the receipts';

  @override
  String get reportMissingReceipts => 'Still missing: the receipts.';

  @override
  String reportDates(String dates) {
    return 'Expenses · $dates';
  }

  @override
  String get reportReceipts => 'RECEIPTS';

  @override
  String receiptLine(String merchant, String day, String paid) {
    return '$merchant · $day · $paid';
  }

  @override
  String receiptNotPaidBack(String amount) {
    return '$amount not paid back';
  }

  @override
  String claimOutOfRange(String paid) {
    return 'Claim more than 0 and at most the $paid paid.';
  }

  @override
  String claimOverPolicy(String breach) {
    return '$breach.';
  }

  @override
  String get paidBack => 'Paid back';

  @override
  String get submitted => 'Submitted';

  @override
  String get submit => 'Submit';

  @override
  String get submitting => 'Submitting';

  @override
  String reportAskToSubmit(String total) {
    return 'The assistant asks to submit the report for $total.';
  }

  @override
  String get planFromInvitation => 'Planning from the invitation';

  @override
  String get planPlanning => 'Planning the trip';

  @override
  String get planPlanned =>
      'Planned within the company policy. Check it before you book.';

  @override
  String get planWordsHint =>
      'Paste an invitation, or say where you go and for what';

  @override
  String get plan => 'Plan';

  @override
  String get planTrip => 'TRIP';

  @override
  String get planMeetings => 'MEETINGS';

  @override
  String get planFlights => 'FLIGHTS';

  @override
  String get planHotel => 'HOTEL';

  @override
  String get planCity => 'City';

  @override
  String get planPurpose => 'What for';

  @override
  String get planMeetingsField => 'Meetings';

  @override
  String get planThere => 'There';

  @override
  String get planHome => 'Home';

  @override
  String get hotel => 'Hotel';

  @override
  String get bookTrip => 'Book trip';

  @override
  String get planTotal => 'Flights and hotel';

  @override
  String planPart(String part) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'city': 'the city',
      'meetings': 'the meetings',
      'outbound': 'the flight there',
      'homebound': 'the flight home',
      'other': 'the hotel',
    });
    return '$_temp0';
  }

  @override
  String planFlightLine(
    String number,
    String departs,
    String arrives,
    String fare,
  ) {
    return '$number · $departs → $arrives · $fare';
  }

  @override
  String planHotelLine(String name, int count, String nightly, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$name · $_temp0 · $nightly a night · $minutes min on foot';
  }

  @override
  String get bookingTitle => 'Add a booking';

  @override
  String get bookingReading => 'Reading the e-mail';

  @override
  String get bookingFilled =>
      'Filled in from the e-mail. Check it before you add it.';

  @override
  String get bookingPick => 'Pick the confirmation you forwarded to Waypoint.';

  @override
  String get bookingFromEmails => 'From your forwarded e-mails';

  @override
  String get changeEmail => 'Change';

  @override
  String get bookingAddress => 'Address';

  @override
  String get bookingCheckIn => 'Check-in';

  @override
  String get bookingCheckOut => 'Check-out';

  @override
  String get bookingPrice => 'Price';

  @override
  String get bookingConfirmation => 'Confirmation';

  @override
  String bookingCheckOutDay(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$day · $_temp0';
  }

  @override
  String bookingNightly(String nightly) {
    return '$nightly a night';
  }

  @override
  String bookingOutsideTrip(String day, String trip) {
    return '$day is outside the trip, $trip.';
  }

  @override
  String bookingCheckInNotBeforeCheckOut(String checkOut) {
    return 'The check-in must be before the check-out, $checkOut.';
  }

  @override
  String bookingCheckOutNotAfterCheckIn(String checkIn) {
    return 'The check-out must be after the check-in, $checkIn.';
  }

  @override
  String get bookingPriceNotPositive => 'The price must be more than 0.';

  @override
  String bookingPart(String part) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'hotel': 'the hotel',
      'address': 'the address',
      'checkIn': 'the check-in',
      'checkOut': 'the check-out',
      'price': 'the price',
      'other': 'the confirmation number',
    });
    return '$_temp0';
  }

  @override
  String tripInboxNews(String from, String subject) {
    return 'From your inbox: $from · $subject';
  }

  @override
  String tripLands(String day, String time) {
    return 'You land $day at $time';
  }

  @override
  String get arrivalDay => 'Arrival day';

  @override
  String warningNoHotelForNight(String day) {
    return 'No hotel for the night of $day';
  }

  @override
  String warningNoHotelBooked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return 'No hotel booked for $_temp0';
  }

  @override
  String breachLandsOnMeetingDay(
    String flight,
    String meeting,
    String morningUntil,
  ) {
    return '$flight lands on the day of the $meeting, which starts before $morningUntil';
  }

  @override
  String breachLandsTooLate(String flight, String meeting) {
    return '$flight lands too late for the $meeting';
  }

  @override
  String breachLeavesTooEarly(String flight, String meeting) {
    return '$flight leaves less than an hour after the $meeting ends';
  }

  @override
  String breachOverNightly(String nightly, String maxNightly) {
    return 'Over the policy: $nightly a night, the limit is $maxNightly';
  }

  @override
  String breachOverMealsPerDay(String mealsPerDay, String left) {
    return 'Meals are paid back up to $mealsPerDay a day, and $left is left for that day';
  }

  @override
  String breachTaxiNotNeeded(String trainArrives, String meetingStarts) {
    return 'The S-Bahn gets you there at $trainArrives, in time for $meetingStarts: the policy allows a taxi only when public transport would make you late';
  }

  @override
  String get nothingPlanned => 'Nothing planned';

  @override
  String flightNumber(String number) {
    return 'Flight $number';
  }

  @override
  String get flightOut => 'Out';

  @override
  String get flightHome => 'Home';

  @override
  String flightTimes(String departs, String arrives) {
    return '$departs → $arrives';
  }

  @override
  String get tooEarly => 'Too early';

  @override
  String hotelTimes(String checkIn, String checkOut) {
    return 'Check-in $checkIn · out $checkOut';
  }

  @override
  String get noHotelText =>
      'Booked one yourself? Add it from its confirmation e-mail.';

  @override
  String get addFromEmail => 'Add from e-mail';

  @override
  String get meeting => 'Meeting';

  @override
  String was(String was) {
    return 'Was $was';
  }

  @override
  String get bookChanges => 'Book changes';

  @override
  String changesNotBooked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0 not booked';
  }

  @override
  String changesBooked(String confirmation) {
    return 'Booked · confirmation $confirmation';
  }

  @override
  String changeBookings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings',
      one: '1 booking',
    );
    return 'Change $_temp0';
  }

  @override
  String changeHotelNights(String hotel, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$hotel, $_temp0';
  }

  @override
  String changeFlightHome(String number) {
    return 'Flight home $number';
  }

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get cancelledByMessage => 'Cancelled by your message';

  @override
  String get approvalReplaced =>
      'The trip changed. Replaced by the request below.';

  @override
  String get approvalUpdating => 'The trip changed. Updating the request…';

  @override
  String get approvalVoided =>
      'No longer valid. The trip changed after the assistant asked.';

  @override
  String get assistant => 'Assistant';

  @override
  String get waitingForYou => 'Waiting for you';

  @override
  String get statusThinking => 'Thinking';

  @override
  String get statusFindingFlights => 'Looking up flights';

  @override
  String get statusMovingMeeting => 'Moving the meeting';

  @override
  String get statusChangingFlightHome => 'Changing the flight home';

  @override
  String get statusChangingHotel => 'Changing the hotel';

  @override
  String get statusWorking => 'Working';

  @override
  String get statusStopping => 'Stopping';

  @override
  String get assistantEmpty =>
      'Ask the assistant to change this trip. It asks you before it books anything.';

  @override
  String get stopped => 'Stopped';

  @override
  String get noticeStopped => 'Stopped.';

  @override
  String get noticeStartedOver => 'New conversation.';

  @override
  String get tripComposerHint => 'Ask about this trip';

  @override
  String stepMeetingMoved(String meeting, String when) {
    return 'Moved $meeting to $when';
  }

  @override
  String stepHotelNights(String hotel, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$hotel: $_temp0';
  }

  @override
  String stepFlightsOn(String origin, String destination, String day) {
    return 'Looked up flights $origin → $destination, $day';
  }

  @override
  String get stepFlights => 'Looked up flights';

  @override
  String stepFlightHome(String number, String when) {
    return 'Flight home: $number, $when';
  }

  @override
  String get noArrivalDay => 'No arrival day for this trip yet.';

  @override
  String get backToTrip => 'Back to the trip';

  @override
  String arrivalDate(String day, String time) {
    return 'Arrival day · $day, landing $time';
  }

  @override
  String get arrivalBookingRide => 'Booking the ride';

  @override
  String get arrivalPlanning => 'Planning your arrival';

  @override
  String get arrivalComposerHint => 'Ask about your arrival';

  @override
  String askBookRide(String mode, String fare) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'taxi': 'a taxi',
      'other': 'the S-Bahn',
    });
    return 'Book $_temp0 for $fare on the company card?';
  }

  @override
  String askMessageHost(String host) {
    return 'Text $host that you are on your way?';
  }

  @override
  String rideMode(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'taxi': 'Taxi',
      'other': 'S-Bahn and a short walk',
    });
    return '$_temp0';
  }

  @override
  String rideLine(int minutes, String fare, String arrives) {
    return '$minutes min · $fare · there at $arrives';
  }

  @override
  String get book => 'Book';

  @override
  String rideBooked(String mode, String reference) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'taxi': 'Taxi $reference, at the rank when you land',
      'other': 'S-Bahn ticket $reference, valid for 2 hours',
    });
    return '$_temp0';
  }

  @override
  String get rideOverPolicy =>
      'Public transport is in time: the policy allows a taxi only when it would make you late.';

  @override
  String hostTold(String name) {
    return '$name knows when you arrive';
  }

  @override
  String hostExpects(String name) {
    return '$name expects you';
  }

  @override
  String textHost(String firstName) {
    return 'Text $firstName';
  }

  @override
  String get noHotel => 'No hotel';

  @override
  String roomReadyAt(String time) {
    return 'Room ready at $time';
  }

  @override
  String checkInFrom(String time) {
    return 'Check-in from $time';
  }

  @override
  String get noCheckIn => 'No check-in booked';

  @override
  String get roomEarly => 'Room early';
}
