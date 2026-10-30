import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The traveller's trips as booked, for every screen of the app.
final class TripsCubit(List<Trip> trips, {required final Inbox inbox})
    extends Cubit<TripsState> {
  this : super(TripsState(trips));

  Trip? tripOrNull(String id) =>
      state.trips.where((trip) => trip.id == id).firstOrNull;

  /// An id that no trip has yet, for a new trip to [city].
  String newId(String city) {
    final name = city.toLowerCase();
    var count = 1;
    while (tripOrNull('$name-$count') != null) {
      count++;
    }
    return '$name-$count';
  }

  /// Records what is now booked for the trip [id].
  void book(String id, Itinerary booked) => emit(
    TripsState([
      for (final trip in state.trips)
        if (trip.id == id) trip.copyWith(booked: booked) else trip,
    ]),
  );

  /// Adds a trip planned and booked in the app, in the order of departure.
  void add(Trip trip) => emit(
    TripsState(
      [...state.trips, trip]..sort(
        (a, b) =>
            a.booked.outbound.departs.compareTo(b.booked.outbound.departs),
      ),
    ),
  );

  /// The forwarded e-mails that the trip [id] does not follow yet, newest
  /// first. Receipts are for the trip's expense report instead.
  List<ForwardedEmail> news(String id) => switch (tripOrNull(id)) {
    final trip? => [
      for (final email in inbox.emails)
        if (email.tripId == id &&
            email.news is! Receipt &&
            !email.isDoneIn(trip.booked))
          email,
    ],
    null => const [],
  };

  /// The invitations whose trip is not planned yet, newest first.
  List<ForwardedEmail> get invitations => [
    for (final email in inbox.emails)
      if (email.news is TripInvitation && tripOrNull(email.tripId) == null)
        email,
  ];

  /// Everything in the inbox that waits for the traveller.
  int get waiting =>
      invitations.length +
      state.trips.fold(0, (count, trip) => count + news(trip.id).length);
}

final class const TripsState(final List<Trip> trips) with Equatable {
  @override
  List<Object?> get props => [trips];
}
