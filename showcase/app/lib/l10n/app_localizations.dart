import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Waypoint'**
  String get appTitle;

  /// Two days of a trip, such as Wed 28 – Fri 30 Oct.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String dateRange(String from, String to);

  /// No description provided for @nights.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 night} other{{count} nights}}'**
  String nights(int count);

  /// The days of a trip and how many nights it has.
  ///
  /// In en, this message translates to:
  /// **'{dates} · {count, plural, =1{1 night} other{{count} nights}}'**
  String tripDates(String dates, int count);

  /// What a trip is for, when the traveller did not say.
  ///
  /// In en, this message translates to:
  /// **'Client work'**
  String get clientWork;

  /// No description provided for @stillMissing.
  ///
  /// In en, this message translates to:
  /// **'Still missing: {items}.'**
  String stillMissing(String items);

  /// Between the items of a list in a sentence, such as what is still missing.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @companyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Company policy: {rules}'**
  String companyPolicy(String rules);

  /// No description provided for @tripPolicy.
  ///
  /// In en, this message translates to:
  /// **'Economy flights. Hotels up to {maxNightly} a night. Arrive the evening before a meeting that starts before {morningUntil}. Fly home at least an hour after the last meeting ends.'**
  String tripPolicy(String maxNightly, String morningUntil);

  /// No description provided for @expensesPolicy.
  ///
  /// In en, this message translates to:
  /// **'Meals are paid back up to {mealsPerDay} a day. Taxis and public transport are paid back in full. Every expense needs its receipt.'**
  String expensesPolicy(String mealsPerDay);

  /// No description provided for @agentUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Waypoint cannot reach the assistant. Check your connection.'**
  String get agentUnreachable;

  /// No description provided for @agentRunFailed.
  ///
  /// In en, this message translates to:
  /// **'The assistant ran into a problem.'**
  String get agentRunFailed;

  /// An approval request of a method that the screen has no own words for.
  ///
  /// In en, this message translates to:
  /// **'The assistant asks to go ahead.'**
  String get approvalFallback;

  /// No description provided for @booking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get booking;

  /// No description provided for @addToTrip.
  ///
  /// In en, this message translates to:
  /// **'Add to trip'**
  String get addToTrip;

  /// No description provided for @adding.
  ///
  /// In en, this message translates to:
  /// **'Adding'**
  String get adding;

  /// No description provided for @noHotelYet.
  ///
  /// In en, this message translates to:
  /// **'No hotel yet'**
  String get noHotelYet;

  /// No description provided for @flightAt.
  ///
  /// In en, this message translates to:
  /// **'{number} · {time}'**
  String flightAt(String number, String time);

  /// No description provided for @flightRoute.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String flightRoute(String from, String to);

  /// No description provided for @meetingTimes.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end} · {place}'**
  String meetingTimes(String start, String end, String place);

  /// No description provided for @tabTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tabTrips;

  /// No description provided for @tabInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get tabInbox;

  /// No description provided for @tabExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get tabExpenses;

  /// No description provided for @tripsTitle.
  ///
  /// In en, this message translates to:
  /// **'TRIPS'**
  String get tripsTitle;

  /// No description provided for @tripsGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String tripsGreeting(String name);

  /// No description provided for @planATrip.
  ///
  /// In en, this message translates to:
  /// **'Plan a trip'**
  String get planATrip;

  /// No description provided for @tripsNeedsYou.
  ///
  /// In en, this message translates to:
  /// **'NEEDS YOU'**
  String get tripsNeedsYou;

  /// No description provided for @tripsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get tripsUpcoming;

  /// No description provided for @tripsPast.
  ///
  /// In en, this message translates to:
  /// **'PAST'**
  String get tripsPast;

  /// No description provided for @invitationTitle.
  ///
  /// In en, this message translates to:
  /// **'{city} · Invitation from {client}'**
  String invitationTitle(String city, String client);

  /// No description provided for @invitationText.
  ///
  /// In en, this message translates to:
  /// **'{from} invites you to {city}. Waypoint plans the trip within your company policy.'**
  String invitationText(String from, String city);

  /// No description provided for @meetingMovedTitle.
  ///
  /// In en, this message translates to:
  /// **'{city} · {subject}'**
  String meetingMovedTitle(String city, String subject);

  /// No description provided for @meetingMovedText.
  ///
  /// In en, this message translates to:
  /// **'{from} moved the {meeting} to {when}. Your flight home and hotel are booked for the old day.'**
  String meetingMovedText(String from, String meeting, String when);

  /// A meeting that an e-mail moves, when the trip does not know it.
  ///
  /// In en, this message translates to:
  /// **'meeting'**
  String get meetingFallback;

  /// No description provided for @hotelToAddTitle.
  ///
  /// In en, this message translates to:
  /// **'{city} · A hotel to add'**
  String hotelToAddTitle(String city);

  /// No description provided for @hotelToAddText.
  ///
  /// In en, this message translates to:
  /// **'{from} confirmed your stay. It is not on the trip yet.'**
  String hotelToAddText(String from);

  /// No description provided for @unknownTrip.
  ///
  /// In en, this message translates to:
  /// **'This trip is not in Waypoint.'**
  String get unknownTrip;

  /// No description provided for @yourTrips.
  ///
  /// In en, this message translates to:
  /// **'Your trips'**
  String get yourTrips;

  /// No description provided for @unknownInvitation.
  ///
  /// In en, this message translates to:
  /// **'This invitation is not in your inbox.'**
  String get unknownInvitation;

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'INBOX'**
  String get inboxTitle;

  /// No description provided for @inboxAbove.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to Waypoint'**
  String get inboxAbove;

  /// No description provided for @emailInReport.
  ///
  /// In en, this message translates to:
  /// **'In your {city} expense report'**
  String emailInReport(String city);

  /// No description provided for @emailOnTrip.
  ///
  /// In en, this message translates to:
  /// **'On your {city} trip'**
  String emailOnTrip(String city);

  /// No description provided for @emailToPlan.
  ///
  /// In en, this message translates to:
  /// **'A trip to {city} to plan'**
  String emailToPlan(String city);

  /// No description provided for @emailChangesTrip.
  ///
  /// In en, this message translates to:
  /// **'Changes your {city} trip'**
  String emailChangesTrip(String city);

  /// No description provided for @emailNotOnTrip.
  ///
  /// In en, this message translates to:
  /// **'Not on your {city} trip yet'**
  String emailNotOnTrip(String city);

  /// No description provided for @emailNoTrip.
  ///
  /// In en, this message translates to:
  /// **'For a trip not planned yet'**
  String get emailNoTrip;

  /// No description provided for @planTheTrip.
  ///
  /// In en, this message translates to:
  /// **'Plan the trip'**
  String get planTheTrip;

  /// No description provided for @reviewTheTrip.
  ///
  /// In en, this message translates to:
  /// **'Review the trip'**
  String get reviewTheTrip;

  /// No description provided for @openTheReport.
  ///
  /// In en, this message translates to:
  /// **'Open the report'**
  String get openTheReport;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'EXPENSES'**
  String get expensesTitle;

  /// No description provided for @expensesAbove.
  ///
  /// In en, this message translates to:
  /// **'After your trips'**
  String get expensesAbove;

  /// No description provided for @expensesNone.
  ///
  /// In en, this message translates to:
  /// **'Your trips are still ahead. Forward their receipts to Waypoint, and the report waits here when you are back.'**
  String get expensesNone;

  /// No description provided for @reportSubmittedLine.
  ///
  /// In en, this message translates to:
  /// **'Submitted · {total} · {confirmation}'**
  String reportSubmittedLine(String total, String confirmation);

  /// No description provided for @reportToSubmit.
  ///
  /// In en, this message translates to:
  /// **'To submit · {count, plural, =1{1 receipt} other{{count} receipts}}'**
  String reportToSubmit(int count);

  /// No description provided for @reportAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding the receipts'**
  String get reportAdding;

  /// No description provided for @reportMissingReceipts.
  ///
  /// In en, this message translates to:
  /// **'Still missing: the receipts.'**
  String get reportMissingReceipts;

  /// No description provided for @reportDates.
  ///
  /// In en, this message translates to:
  /// **'Expenses · {dates}'**
  String reportDates(String dates);

  /// No description provided for @reportReceipts.
  ///
  /// In en, this message translates to:
  /// **'RECEIPTS'**
  String get reportReceipts;

  /// No description provided for @receiptLine.
  ///
  /// In en, this message translates to:
  /// **'{merchant} · {day} · {paid}'**
  String receiptLine(String merchant, String day, String paid);

  /// No description provided for @receiptNotPaidBack.
  ///
  /// In en, this message translates to:
  /// **'{amount} not paid back'**
  String receiptNotPaidBack(String amount);

  /// No description provided for @claimOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Claim more than 0 and at most the {paid} paid.'**
  String claimOutOfRange(String paid);

  /// No description provided for @claimOverPolicy.
  ///
  /// In en, this message translates to:
  /// **'{breach}.'**
  String claimOverPolicy(String breach);

  /// No description provided for @paidBack.
  ///
  /// In en, this message translates to:
  /// **'Paid back'**
  String get paidBack;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting'**
  String get submitting;

  /// No description provided for @reportAskToSubmit.
  ///
  /// In en, this message translates to:
  /// **'The assistant asks to submit the report for {total}.'**
  String reportAskToSubmit(String total);

  /// No description provided for @planFromInvitation.
  ///
  /// In en, this message translates to:
  /// **'Planning from the invitation'**
  String get planFromInvitation;

  /// No description provided for @planPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning the trip'**
  String get planPlanning;

  /// No description provided for @planPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned within the company policy. Check it before you book.'**
  String get planPlanned;

  /// No description provided for @planWordsHint.
  ///
  /// In en, this message translates to:
  /// **'Paste an invitation, or say where you go and for what'**
  String get planWordsHint;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @planTrip.
  ///
  /// In en, this message translates to:
  /// **'TRIP'**
  String get planTrip;

  /// No description provided for @planMeetings.
  ///
  /// In en, this message translates to:
  /// **'MEETINGS'**
  String get planMeetings;

  /// No description provided for @planFlights.
  ///
  /// In en, this message translates to:
  /// **'FLIGHTS'**
  String get planFlights;

  /// No description provided for @planHotel.
  ///
  /// In en, this message translates to:
  /// **'HOTEL'**
  String get planHotel;

  /// No description provided for @planCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get planCity;

  /// No description provided for @planPurpose.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get planPurpose;

  /// No description provided for @planMeetingsField.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get planMeetingsField;

  /// No description provided for @planThere.
  ///
  /// In en, this message translates to:
  /// **'There'**
  String get planThere;

  /// No description provided for @planHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get planHome;

  /// No description provided for @hotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get hotel;

  /// No description provided for @bookTrip.
  ///
  /// In en, this message translates to:
  /// **'Book trip'**
  String get bookTrip;

  /// No description provided for @planTotal.
  ///
  /// In en, this message translates to:
  /// **'Flights and hotel'**
  String get planTotal;

  /// A part of a planned trip that is still missing.
  ///
  /// In en, this message translates to:
  /// **'{part, select, city{the city} meetings{the meetings} outbound{the flight there} homebound{the flight home} other{the hotel}}'**
  String planPart(String part);

  /// No description provided for @planFlightLine.
  ///
  /// In en, this message translates to:
  /// **'{number} · {departs} → {arrives} · {fare}'**
  String planFlightLine(
    String number,
    String departs,
    String arrives,
    String fare,
  );

  /// No description provided for @planHotelLine.
  ///
  /// In en, this message translates to:
  /// **'{name} · {count, plural, =1{1 night} other{{count} nights}} · {nightly} a night · {minutes} min on foot'**
  String planHotelLine(String name, int count, String nightly, int minutes);

  /// No description provided for @bookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a booking'**
  String get bookingTitle;

  /// No description provided for @bookingReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the e-mail'**
  String get bookingReading;

  /// No description provided for @bookingFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled in from the e-mail. Check it before you add it.'**
  String get bookingFilled;

  /// No description provided for @bookingPick.
  ///
  /// In en, this message translates to:
  /// **'Pick the confirmation you forwarded to Waypoint.'**
  String get bookingPick;

  /// No description provided for @bookingFromEmails.
  ///
  /// In en, this message translates to:
  /// **'From your forwarded e-mails'**
  String get bookingFromEmails;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeEmail;

  /// No description provided for @bookingAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get bookingAddress;

  /// No description provided for @bookingCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get bookingCheckIn;

  /// No description provided for @bookingCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get bookingCheckOut;

  /// No description provided for @bookingPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get bookingPrice;

  /// No description provided for @bookingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get bookingConfirmation;

  /// No description provided for @bookingCheckOutDay.
  ///
  /// In en, this message translates to:
  /// **'{day} · {count, plural, =1{1 night} other{{count} nights}}'**
  String bookingCheckOutDay(String day, int count);

  /// No description provided for @bookingNightly.
  ///
  /// In en, this message translates to:
  /// **'{nightly} a night'**
  String bookingNightly(String nightly);

  /// No description provided for @bookingOutsideTrip.
  ///
  /// In en, this message translates to:
  /// **'{day} is outside the trip, {trip}.'**
  String bookingOutsideTrip(String day, String trip);

  /// No description provided for @bookingCheckInNotBeforeCheckOut.
  ///
  /// In en, this message translates to:
  /// **'The check-in must be before the check-out, {checkOut}.'**
  String bookingCheckInNotBeforeCheckOut(String checkOut);

  /// No description provided for @bookingCheckOutNotAfterCheckIn.
  ///
  /// In en, this message translates to:
  /// **'The check-out must be after the check-in, {checkIn}.'**
  String bookingCheckOutNotAfterCheckIn(String checkIn);

  /// No description provided for @bookingPriceNotPositive.
  ///
  /// In en, this message translates to:
  /// **'The price must be more than 0.'**
  String get bookingPriceNotPositive;

  /// A part of a hotel booking that is still missing.
  ///
  /// In en, this message translates to:
  /// **'{part, select, hotel{the hotel} address{the address} checkIn{the check-in} checkOut{the check-out} price{the price} other{the confirmation number}}'**
  String bookingPart(String part);

  /// No description provided for @tripInboxNews.
  ///
  /// In en, this message translates to:
  /// **'From your inbox: {from} · {subject}'**
  String tripInboxNews(String from, String subject);

  /// No description provided for @tripLands.
  ///
  /// In en, this message translates to:
  /// **'You land {day} at {time}'**
  String tripLands(String day, String time);

  /// No description provided for @arrivalDay.
  ///
  /// In en, this message translates to:
  /// **'Arrival day'**
  String get arrivalDay;

  /// No description provided for @warningNoHotelForNight.
  ///
  /// In en, this message translates to:
  /// **'No hotel for the night of {day}'**
  String warningNoHotelForNight(String day);

  /// No description provided for @warningNoHotelBooked.
  ///
  /// In en, this message translates to:
  /// **'No hotel booked for {count, plural, =1{1 night} other{{count} nights}}'**
  String warningNoHotelBooked(int count);

  /// No description provided for @breachLandsOnMeetingDay.
  ///
  /// In en, this message translates to:
  /// **'{flight} lands on the day of the {meeting}, which starts before {morningUntil}'**
  String breachLandsOnMeetingDay(
    String flight,
    String meeting,
    String morningUntil,
  );

  /// No description provided for @breachLandsTooLate.
  ///
  /// In en, this message translates to:
  /// **'{flight} lands too late for the {meeting}'**
  String breachLandsTooLate(String flight, String meeting);

  /// No description provided for @breachLeavesTooEarly.
  ///
  /// In en, this message translates to:
  /// **'{flight} leaves less than an hour after the {meeting} ends'**
  String breachLeavesTooEarly(String flight, String meeting);

  /// No description provided for @breachOverNightly.
  ///
  /// In en, this message translates to:
  /// **'Over the policy: {nightly} a night, the limit is {maxNightly}'**
  String breachOverNightly(String nightly, String maxNightly);

  /// No description provided for @breachOverMealsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Meals are paid back up to {mealsPerDay} a day, and {left} is left for that day'**
  String breachOverMealsPerDay(String mealsPerDay, String left);

  /// No description provided for @breachTaxiNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'The S-Bahn gets you there at {trainArrives}, in time for {meetingStarts}: the policy allows a taxi only when public transport would make you late'**
  String breachTaxiNotNeeded(String trainArrives, String meetingStarts);

  /// No description provided for @nothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get nothingPlanned;

  /// No description provided for @flightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight {number}'**
  String flightNumber(String number);

  /// No description provided for @flightOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get flightOut;

  /// No description provided for @flightHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get flightHome;

  /// No description provided for @flightTimes.
  ///
  /// In en, this message translates to:
  /// **'{departs} → {arrives}'**
  String flightTimes(String departs, String arrives);

  /// No description provided for @tooEarly.
  ///
  /// In en, this message translates to:
  /// **'Too early'**
  String get tooEarly;

  /// No description provided for @hotelTimes.
  ///
  /// In en, this message translates to:
  /// **'Check-in {checkIn} · out {checkOut}'**
  String hotelTimes(String checkIn, String checkOut);

  /// No description provided for @noHotelText.
  ///
  /// In en, this message translates to:
  /// **'Booked one yourself? Add it from its confirmation e-mail.'**
  String get noHotelText;

  /// No description provided for @addFromEmail.
  ///
  /// In en, this message translates to:
  /// **'Add from e-mail'**
  String get addFromEmail;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// What a booking was before its change, struck through.
  ///
  /// In en, this message translates to:
  /// **'Was {was}'**
  String was(String was);

  /// No description provided for @bookChanges.
  ///
  /// In en, this message translates to:
  /// **'Book changes'**
  String get bookChanges;

  /// No description provided for @changesNotBooked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change} other{{count} changes}} not booked'**
  String changesNotBooked(int count);

  /// No description provided for @changesBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked · confirmation {confirmation}'**
  String changesBooked(String confirmation);

  /// No description provided for @changeBookings.
  ///
  /// In en, this message translates to:
  /// **'Change {count, plural, =1{1 booking} other{{count} bookings}}'**
  String changeBookings(int count);

  /// No description provided for @changeHotelNights.
  ///
  /// In en, this message translates to:
  /// **'{hotel}, {count, plural, =1{1 night} other{{count} nights}}'**
  String changeHotelNights(String hotel, int count);

  /// No description provided for @changeFlightHome.
  ///
  /// In en, this message translates to:
  /// **'Flight home {number}'**
  String changeFlightHome(String number);

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @cancelledByMessage.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by your message'**
  String get cancelledByMessage;

  /// No description provided for @approvalReplaced.
  ///
  /// In en, this message translates to:
  /// **'The trip changed. Replaced by the request below.'**
  String get approvalReplaced;

  /// No description provided for @approvalUpdating.
  ///
  /// In en, this message translates to:
  /// **'The trip changed. Updating the request…'**
  String get approvalUpdating;

  /// No description provided for @approvalVoided.
  ///
  /// In en, this message translates to:
  /// **'No longer valid. The trip changed after the assistant asked.'**
  String get approvalVoided;

  /// No description provided for @assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @waitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get waitingForYou;

  /// No description provided for @statusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get statusThinking;

  /// No description provided for @statusFindingFlights.
  ///
  /// In en, this message translates to:
  /// **'Looking up flights'**
  String get statusFindingFlights;

  /// No description provided for @statusMovingMeeting.
  ///
  /// In en, this message translates to:
  /// **'Moving the meeting'**
  String get statusMovingMeeting;

  /// No description provided for @statusChangingFlightHome.
  ///
  /// In en, this message translates to:
  /// **'Changing the flight home'**
  String get statusChangingFlightHome;

  /// No description provided for @statusChangingHotel.
  ///
  /// In en, this message translates to:
  /// **'Changing the hotel'**
  String get statusChangingHotel;

  /// No description provided for @statusWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get statusWorking;

  /// No description provided for @statusStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get statusStopping;

  /// No description provided for @assistantEmpty.
  ///
  /// In en, this message translates to:
  /// **'Ask the assistant to change this trip. It asks you before it books anything.'**
  String get assistantEmpty;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @noticeStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get noticeStopped;

  /// No description provided for @noticeStartedOver.
  ///
  /// In en, this message translates to:
  /// **'New conversation.'**
  String get noticeStartedOver;

  /// No description provided for @tripComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about this trip'**
  String get tripComposerHint;

  /// No description provided for @stepMeetingMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved {meeting} to {when}'**
  String stepMeetingMoved(String meeting, String when);

  /// No description provided for @stepHotelNights.
  ///
  /// In en, this message translates to:
  /// **'{hotel}: {count, plural, =1{1 night} other{{count} nights}}'**
  String stepHotelNights(String hotel, int count);

  /// No description provided for @stepFlightsOn.
  ///
  /// In en, this message translates to:
  /// **'Looked up flights {origin} → {destination}, {day}'**
  String stepFlightsOn(String origin, String destination, String day);

  /// No description provided for @stepFlights.
  ///
  /// In en, this message translates to:
  /// **'Looked up flights'**
  String get stepFlights;

  /// No description provided for @stepFlightHome.
  ///
  /// In en, this message translates to:
  /// **'Flight home: {number}, {when}'**
  String stepFlightHome(String number, String when);

  /// No description provided for @noArrivalDay.
  ///
  /// In en, this message translates to:
  /// **'No arrival day for this trip yet.'**
  String get noArrivalDay;

  /// No description provided for @backToTrip.
  ///
  /// In en, this message translates to:
  /// **'Back to the trip'**
  String get backToTrip;

  /// No description provided for @arrivalDate.
  ///
  /// In en, this message translates to:
  /// **'Arrival day · {day}, landing {time}'**
  String arrivalDate(String day, String time);

  /// No description provided for @arrivalBookingRide.
  ///
  /// In en, this message translates to:
  /// **'Booking the ride'**
  String get arrivalBookingRide;

  /// No description provided for @arrivalPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning your arrival'**
  String get arrivalPlanning;

  /// No description provided for @arrivalComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your arrival'**
  String get arrivalComposerHint;

  /// No description provided for @askBookRide.
  ///
  /// In en, this message translates to:
  /// **'Book {mode, select, taxi{a taxi} other{the S-Bahn}} for {fare} on the company card?'**
  String askBookRide(String mode, String fare);

  /// No description provided for @askMessageHost.
  ///
  /// In en, this message translates to:
  /// **'Text {host} that you are on your way?'**
  String askMessageHost(String host);

  /// No description provided for @rideMode.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, taxi{Taxi} other{S-Bahn and a short walk}}'**
  String rideMode(String mode);

  /// No description provided for @rideLine.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · {fare} · there at {arrives}'**
  String rideLine(int minutes, String fare, String arrives);

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @rideBooked.
  ///
  /// In en, this message translates to:
  /// **'{mode, select, taxi{Taxi {reference}, at the rank when you land} other{S-Bahn ticket {reference}, valid for 2 hours}}'**
  String rideBooked(String mode, String reference);

  /// No description provided for @rideOverPolicy.
  ///
  /// In en, this message translates to:
  /// **'Public transport is in time: the policy allows a taxi only when it would make you late.'**
  String get rideOverPolicy;

  /// No description provided for @hostTold.
  ///
  /// In en, this message translates to:
  /// **'{name} knows when you arrive'**
  String hostTold(String name);

  /// No description provided for @hostExpects.
  ///
  /// In en, this message translates to:
  /// **'{name} expects you'**
  String hostExpects(String name);

  /// No description provided for @textHost.
  ///
  /// In en, this message translates to:
  /// **'Text {firstName}'**
  String textHost(String firstName);

  /// No description provided for @noHotel.
  ///
  /// In en, this message translates to:
  /// **'No hotel'**
  String get noHotel;

  /// No description provided for @roomReadyAt.
  ///
  /// In en, this message translates to:
  /// **'Room ready at {time}'**
  String roomReadyAt(String time);

  /// No description provided for @checkInFrom.
  ///
  /// In en, this message translates to:
  /// **'Check-in from {time}'**
  String checkInFrom(String time);

  /// No description provided for @noCheckIn.
  ///
  /// In en, this message translates to:
  /// **'No check-in booked'**
  String get noCheckIn;

  /// No description provided for @roomEarly.
  ///
  /// In en, this message translates to:
  /// **'Room early'**
  String get roomEarly;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
