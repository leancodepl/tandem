class const Customer({
  required final String id,
  required final String name,

  /// The person at the customer who sends the orders.
  required final String contact,
  required final String priceList,
});

class Customers(final List<Customer> all) {
  /// The customer with [id]; throws an [ArgumentError] for none.
  Customer byId(String id) => all.firstWhere(
    (customer) => customer.id == id,
    orElse: () => throw ArgumentError.value(id, 'customerId', 'is unknown'),
  );
}
