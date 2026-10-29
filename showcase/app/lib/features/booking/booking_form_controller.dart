import 'package:advanced_forms/advanced_forms.dart';
import 'package:equatable/equatable.dart';
import 'package:waypoint/common/dates/date_only.dart';
import 'package:waypoint/common/formatters/agent_formatters.dart';
import 'package:waypoint_travel/waypoint_travel.dart';

/// The hotel booking form, for a trip from [tripStart] to [tripEnd].
final class BookingFormController({
  required final DateTime tripStart,
  required final DateTime tripEnd,
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

  final hotel = AdvancedTextFieldController<BookingError>();
  final address = AdvancedTextFieldController<BookingError>();
  late final AdvancedFieldController<DateTime?, BookingError> checkIn =
      AdvancedFieldController(initialValue: null, validator: checkInError);
  late final AdvancedFieldController<DateTime?, BookingError> checkOut =
      AdvancedFieldController(initialValue: null, validator: checkOutError);
  late final AdvancedTextFieldController<BookingError> totalPrice =
      AdvancedTextFieldController(validator: totalPriceError);
  final confirmation = AdvancedTextFieldController<BookingError>();

  BookingError? checkInError(DateTime? at) {
    if (at == null) return null;
    if (_outsideTrip(at) case final outside?) return outside;
    if (checkOut.fieldValue case final out?
        when !dateOnly(at).isBefore(dateOnly(out))) {
      return CheckInNotBeforeCheckOut(out);
    }
    return null;
  }

  BookingError? checkOutError(DateTime? day) {
    if (day == null) return null;
    if (_outsideTrip(day) case final outside?) return outside;
    if (checkIn.fieldValue case final at?
        when !dateOnly(day).isAfter(dateOnly(at))) {
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

  /// The booking as the form holds it, with blank text as not filled in.
  BookingDraft get draft => BookingDraft(
    hotel: _filled(hotel.fieldValue),
    address: _filled(address.fieldValue),
    checkIn: checkIn.fieldValue,
    checkOut: checkOut.fieldValue,
    totalPrice: int.tryParse(totalPrice.fieldValue.trim()),
    confirmation: _filled(confirmation.fieldValue),
  );

  /// What is still missing before the stay can join the trip.
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

  /// The stay to add to the trip, once every field is filled in.
  HotelStay? get stay => switch (draft) {
    BookingDraft(
      :final hotel?,
      :final address?,
      :final checkIn?,
      :final nights?,
      :final totalPrice?,
      :final confirmation?,
    )
        when nights >= 1 =>
      HotelStay(
        name: hotel,
        address: address,
        checkIn: checkIn,
        nights: nights,
        nightly: (totalPrice / nights).round(),
        confirmation: confirmation,
      ),
    _ => null,
  };

  OutsideTrip? _outsideTrip(DateTime at) {
    final day = dateOnly(at);
    if (day.isBefore(dateOnly(tripStart)) || day.isAfter(dateOnly(tripEnd))) {
      return OutsideTrip(day, tripStart: tripStart, tripEnd: tripEnd);
    }
    return null;
  }

  static String? _filled(String text) => switch (text.trim()) {
    '' => null,
    final text => text,
  };
}

/// A hotel booking as read from its confirmation, before it joins the trip.
final class const BookingDraft({
  final String? hotel,
  final String? address,
  final DateTime? checkIn,
  final DateTime? checkOut,
  final int? totalPrice,
  final String? confirmation,
}) {
  int? get nights => switch ((checkIn, checkOut)) {
    (final from?, final to?) => dateOnly(to).difference(dateOnly(from)).inDays,
    _ => null,
  };
}

/// What a hotel booking can miss.
enum BookingPart() {
  hotel,
  address,
  checkIn,
  checkOut,
  price,
  confirmation,
}

/// Why a field of the booking form holds a wrong value.
sealed class const BookingError() with Equatable {
  /// The error in English, for the agent.
  String get forAgent;
}

/// [day] cannot be part of the stay: the trip runs from [tripStart] to
/// [tripEnd].
final class const OutsideTrip(
  final DateTime day, {
  required final DateTime tripStart,
  required final DateTime tripEnd,
}) extends BookingError {
  @override
  List<Object?> get props => [day, tripStart, tripEnd];

  @override
  String get forAgent =>
      '${_dayForAgent(day)} is outside the trip, '
      '${dayRangeForAgent(tripStart, tripEnd)}';
}

/// The check-in is on or after the [checkOut] day.
final class const CheckInNotBeforeCheckOut(final DateTime checkOut)
    extends BookingError {
  @override
  List<Object?> get props => [checkOut];

  @override
  String get forAgent =>
      'The check-in must be before the check-out, ${_dayForAgent(checkOut)}; '
      'to move the stay later, set the check-out first';
}

/// The check-out is on or before the [checkIn] day.
final class const CheckOutNotAfterCheckIn(final DateTime checkIn)
    extends BookingError {
  @override
  List<Object?> get props => [checkIn];

  @override
  String get forAgent =>
      'The check-out must be after the check-in, ${_dayForAgent(checkIn)}';
}

/// The price is not a whole number of euros above 0.
final class const PriceNotPositive() extends BookingError {
  @override
  List<Object?> get props => [];

  @override
  String get forAgent => 'The price must be more than 0';
}

/// 2026-10-28
String _dayForAgent(DateTime day) => day.toIso8601String().substring(0, 10);
