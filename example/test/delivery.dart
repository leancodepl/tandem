/// Where and when an order goes.
class const Delivery({
  /// Where the courier brings the order.
  required final Address address,

  /// The day the order arrives.
  required final DateTime day,
  final DeliverySlot slot = .morning,

  /// Anything the courier should know.
  final String? note,
});

/// A street address.
class const Address({required final String street, required final String city});

enum DeliverySlot() {
  morning,
  afternoon,
}
