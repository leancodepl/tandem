import 'package:equatable/equatable.dart';

final class TripId(String value) extends _Identifier<TripId> {
  this : super(value.trim());

  static TripId? tryParse(String value) =>
      value.trim().isEmpty ? null : TripId(value);
}

final class MeetingId(String value) extends _Identifier<MeetingId> {
  this : super(value.trim());

  static MeetingId? tryParse(String value) =>
      value.trim().isEmpty ? null : MeetingId(value);
}

final class HotelId(String value) extends _Identifier<HotelId> {
  this : super(value.trim());

  static HotelId? tryParse(String value) =>
      value.trim().isEmpty ? null : HotelId(value);
}

final class RideId(String value) extends _Identifier<RideId> {
  this : super(value.trim());

  static RideId? tryParse(String value) =>
      value.trim().isEmpty ? null : RideId(value);
}

final class ReceiptId(String value) extends _Identifier<ReceiptId> {
  this : super(value.trim());

  static ReceiptId? tryParse(String value) =>
      value.trim().isEmpty ? null : ReceiptId(value);
}

final class BookingReference(String value)
    extends _Identifier<BookingReference> {
  this : super(value.trim());

  static BookingReference? tryParse(String value) =>
      value.trim().isEmpty ? null : BookingReference(value);
}

sealed class _Identifier<T extends _Identifier<T>>(final String value)
    with Equatable
    implements Comparable<T> {
  this {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'An identifier is not empty.');
    }
  }

  @override
  int compareTo(T other) => value.compareTo(other.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
