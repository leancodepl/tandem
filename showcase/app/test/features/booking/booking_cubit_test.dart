import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';
import 'package:waypoint/features/booking/booking_cubit.dart';
import 'package:waypoint/features/booking/booking_form_controller.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

void main() {
  late BookingFormController form;
  late BookingCubit booking;

  setUp(() {
    form = BookingFormController(
      tripStart: DateTime(2026, 10, 28, 7, 15),
      tripEnd: DateTime(2026, 10, 30, 18, 5),
    );
    booking = BookingCubit(form: form);
  });

  tearDown(() async {
    await booking.close();
    form.dispose();
  });

  void fill({String hotel = 'Spree Loft Hotel'}) => booking
    ..setHotel(hotel)
    ..setAddress('Am Wriezener Bahnhof 2, 10243 Berlin')
    ..setCheckIn(DateTime(2026, 10, 28, 15))
    ..setCheckOut(DateTime(2026, 10, 29))
    ..setTotalPrice(122)
    ..setConfirmation(' 84213907 ');

  test('a day outside the trip is refused', () {
    expect(
      () => booking.setCheckOut(DateTime(2026, 10, 31)),
      throwsA(isA<ToolCallRefused>()),
    );
    expect(form.checkOut.fieldValue, isNull);
  });

  test('a stay costs more than nothing', () {
    expect(() => booking.setTotalPrice(0), throwsA(isA<ToolCallRefused>()));
  });

  test('a check-out on the day of the check-in is refused', () {
    booking.setCheckIn(DateTime(2026, 10, 28, 15));

    expect(
      () => booking.setCheckOut(DateTime(2026, 10, 28)),
      throwsA(
        isA<ToolCallRefused>().having(
          (refusal) => refusal.message,
          'message',
          contains('after the check-in'),
        ),
      ),
    );
  });

  test('a check-in moved onto the check-out is refused', () {
    booking
      ..setCheckIn(DateTime(2026, 10, 28, 15))
      ..setCheckOut(DateTime(2026, 10, 29));

    expect(
      () => booking.setCheckIn(DateTime(2026, 10, 29, 15)),
      throwsA(
        isA<ToolCallRefused>().having(
          (refusal) => refusal.message,
          'message',
          contains('set the check-out first'),
        ),
      ),
    );
    expect(form.checkIn.fieldValue, DateTime(2026, 10, 28, 15));
  });

  test('the stay is ready once every field is filled', () async {
    booking
      ..setHotel('Spree Loft Hotel')
      ..setAddress('Am Wriezener Bahnhof 2, 10243 Berlin')
      ..setCheckIn(DateTime(2026, 10, 28, 15))
      ..setCheckOut(DateTime(2026, 10, 29))
      ..setTotalPrice(122);
    expect(booking.ready, isFalse);

    booking.setConfirmation(' 84213907 ');
    expect(booking.ready, isTrue);

    final stay = await _add(booking);
    expect(stay?.nights, 1);
    expect(stay?.nightly, 122);
    expect(stay?.confirmation, '84213907');
  });

  test('a hotel of only spaces is missing', () {
    fill(hotel: '  ');

    expect(form.missing, [BookingPart.hotel]);
    expect(booking.ready, isFalse);
  });

  test('a wrong value holds the stay back', () async {
    fill();

    form.totalPrice.textController.text = '0';

    expect(form.missing, isEmpty);
    expect(form.totalPrice.error, const PriceNotPositive());
    expect(booking.ready, isFalse);
    expect(await _add(booking), isNull);
  });

  test('another e-mail starts from an empty form', () {
    fill();

    booking.clear();

    expect(form.missing, BookingPart.values);
    expect(booking.state.marked, isEmpty);
  });

  test('the price a night is the total over the nights, rounded', () {
    fill();
    booking
      ..setCheckOut(DateTime(2026, 10, 30))
      ..setTotalPrice(245);

    expect(form.stay?.nightly, 123);
  });

  test("the traveller's edit is what the agent sees", () {
    form.totalPrice.textController.text = '130';

    final draft = AgentListing.of(booking).seen['draft'];
    expect(draft, containsPair('totalPrice', 130));
  });
}

/// Adds the stay of [booking] and gives the one it added, or null when it
/// added none.
Future<HotelStay?> _add(BookingCubit booking) async {
  final stays = <HotelStay>[];
  final added = booking.presentation.listen(
    (event) => switch (event) {
      BookingPresentationEventAdded(:final stay) => stays.add(stay),
    },
  );
  await booking.add();
  // The event comes in a later microtask than the end of add().
  await Future<void>.delayed(Duration.zero);
  await added.cancel();
  return stays.singleOrNull;
}
