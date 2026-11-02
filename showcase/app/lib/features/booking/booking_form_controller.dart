import 'package:advanced_forms/advanced_forms.dart';
import 'package:waypoint/features/booking/booking_draft.dart';
import 'package:waypoint/features/booking/booking_error.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

final class BookingFormController({
  required DateTime tripStart,
  required DateTime tripEnd,
}) extends AdvancedFormController {
  this : super(validationMode: .onUserInteraction) {
    registerFields([
      hotel,
      address,
      checkIn,
      checkOut,
      totalPrice,
      confirmation,
    ]);
    checkIn.subscribeToFields([checkOut]);
    checkOut.subscribeToFields([checkIn]);
  }

  DateTime _tripStart = tripStart;
  DateTime _tripEnd = tripEnd;

  DateTime get tripStart => _tripStart;
  DateTime get tripEnd => _tripEnd;

  final hotel = AdvancedTextFieldController<BookingError>();
  final address = AdvancedTextFieldController<BookingError>();
  late final AdvancedFieldController<DateTime?, BookingError> checkIn =
      AdvancedFieldController(initialValue: null, validator: checkInError);
  late final AdvancedFieldController<DateTime?, BookingError> checkOut =
      AdvancedFieldController(initialValue: null, validator: checkOutError);
  late final AdvancedTextFieldController<BookingError> totalPrice =
      AdvancedTextFieldController(validator: totalPriceError);
  final confirmation = AdvancedTextFieldController<BookingError>();

  void updateTripDates({required DateTime start, required DateTime end}) {
    if (start == tripStart && end == tripEnd) return;
    _tripStart = start;
    _tripEnd = end;
    checkIn.revalidateSync();
    checkOut.revalidateSync();
    notifyListeners();
  }

  BookingError? checkInError(DateTime? at) {
    if (at == null) return null;
    if (_outsideTrip(at) case final outside?) return outside;
    if (checkOut.fieldValue case final out?
        when calendarDaysBetween(at, out) <= 0) {
      return CheckInNotBeforeCheckOut(out);
    }
    return null;
  }

  BookingError? checkOutError(DateTime? day) {
    if (day == null) return null;
    if (_outsideTrip(day) case final outside?) return outside;
    if (checkIn.fieldValue case final at?
        when calendarDaysBetween(at, day) <= 0) {
      return CheckOutNotAfterCheckIn(at);
    }
    return null;
  }

  BookingError? totalPriceError(String text) {
    if (text.trim().isEmpty) return null;
    return switch (int.tryParse(text.trim())) {
      final euros? when euros > 0 => null,
      _ => const PriceNotPositive(),
    };
  }

  BookingDraft get draft => BookingDraft(
    hotel: _filled(hotel.fieldValue),
    address: _filled(address.fieldValue),
    checkIn: checkIn.fieldValue,
    checkOut: checkOut.fieldValue,
    totalPrice: int.tryParse(totalPrice.fieldValue.trim()),
    confirmation: _filled(confirmation.fieldValue),
  );

  List<BookingPart> get missing {
    final draft = this.draft;
    return [
      if (draft.hotel == null) .hotel,
      if (draft.address == null) .address,
      if (draft.checkIn == null) .checkIn,
      if (draft.checkOut == null) .checkOut,
      if (draft.totalPrice == null) .price,
      if (draft.confirmation == null) .confirmation,
    ];
  }

  /// [day] at the time of the check-in the form holds, or at 15:00.
  DateTime checkInOn(DateTime day) {
    final at = checkIn.fieldValue ?? DateTime(0, 1, 1, 15);
    return DateTime(day.year, day.month, day.day, at.hour, at.minute);
  }

  HotelStay? get stay => switch (draft) {
    BookingDraft(
      :final hotel?,
      :final address?,
      :final checkIn?,
      :final nights?,
      :final totalPrice?,
      :final confirmation?,
    )
        when nights >= 1 && totalPrice > 0 =>
      HotelStay.forTotal(
        name: hotel,
        address: address,
        checkIn: checkIn,
        nights: NightCount(nights),
        total: wholeMoney(totalPrice),
        confirmation: BookingReference(confirmation),
      ),
    _ => null,
  };

  OutsideTrip? _outsideTrip(DateTime at) {
    final day = calendarDay(at);
    if (calendarDaysBetween(tripStart, day) < 0 ||
        calendarDaysBetween(day, tripEnd) < 0) {
      return OutsideTrip(day, tripStart: tripStart, tripEnd: tripEnd);
    }
    return null;
  }

  static String? _filled(String text) => switch (text.trim()) {
    '' => null,
    final text => text,
  };
}
