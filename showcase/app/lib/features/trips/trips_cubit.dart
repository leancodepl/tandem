import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class TripsCubit(List<Trip> trips, {required final Inbox inbox})
    extends Cubit<TripsState> {
  this : super(TripsState(trips));

  Trip? tripOrNull(TripId? id) =>
      state.trips.where((trip) => trip.id == id).firstOrNull;

  TripId newId(String city) {
    final name = city.toLowerCase();
    var count = 1;
    while (tripOrNull(TripId('$name-$count')) != null ||
        state.pendingBookings.contains(TripId('$name-$count'))) {
      count++;
    }
    return TripId('$name-$count');
  }

  void book(TripId id, Itinerary booked) => emit(
    TripsState([
      for (final trip in state.trips)
        if (trip.id == id) trip.copyWith(booked: booked) else trip,
    ], pendingBookings: state.pendingBookings),
  );

  void add(Trip trip) {
    emit(
      TripsState(
        [...state.trips, trip]..sort(
          (a, b) =>
              a.booked.outbound.departs.compareTo(b.booked.outbound.departs),
        ),
        pendingBookings: state.pendingBookings,
      ),
    );
  }

  bool reserveBooking(TripId id) {
    if (state.pendingBookings.contains(id)) return false;
    emit(
      TripsState(state.trips, pendingBookings: {...state.pendingBookings, id}),
    );
    return true;
  }

  void releaseBooking(TripId id) => emit(
    TripsState(
      state.trips,
      pendingBookings: {...state.pendingBookings}..remove(id),
    ),
  );

  void confirmHotel(TripId id, HotelStay hotel) {
    final trip = tripOrNull(id);
    if (trip == null) return;
    book(id, trip.booked.copyWith(hotel: hotel));
  }

  void moveMeeting(TripId id, Meeting moved) {
    final trip = tripOrNull(id);
    if (trip == null) return;
    book(
      id,
      trip.booked.copyWith(
        meetings: [
          for (final meeting in trip.booked.meetings)
            if (meeting.id == moved.id) moved else meeting,
        ],
      ),
    );
  }

  bool tryCompleteBooking(
    TripId id, {
    required Itinerary previouslyBooked,
    required Itinerary requested,
  }) {
    final latest = tripOrNull(id)?.booked ?? previouslyBooked;
    final amendsHotelNights =
        requested.hotel?.nights != previouslyBooked.hotel?.nights;
    if (amendsHotelNights && latest.hotel != previouslyBooked.hotel) {
      return false;
    }
    book(
      id,
      requested.copyWith(
        hotel: latest.hotel != previouslyBooked.hotel
            ? latest.hotel
            : requested.hotel,
        meetings: latest.meetings,
      ),
    );
    return true;
  }

  /// Receipts belong to the expense report.
  List<ForwardedEmail> news(TripId id) => switch (tripOrNull(id)) {
    final trip? => [
      for (final email in inbox.emails)
        if (email.tripId == id &&
            email.news is! Receipt &&
            !email.isDoneIn(trip.booked))
          email,
    ],
    null => const [],
  };

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

final class TripsState(
  List<Trip> trips, {
  Set<TripId> pendingBookings = const {},
}) with Equatable {
  this {
    final ids = <TripId>{};
    for (final trip in trips) {
      if (ids.add(trip.id)) continue;
      throw ArgumentError.value(trip.id, 'trips', 'Duplicate trip id');
    }
  }

  final List<Trip> trips = List.unmodifiable(trips);
  final Set<TripId> pendingBookings = Set.unmodifiable(pendingBookings);

  @override
  List<Object?> get props => [trips, pendingBookings];
}
