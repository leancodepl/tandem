class const Customer({
  required final String id,
  required final String name,

  /// The person at the customer who sends the orders.
  required final String contact,
  required final String priceList,
});

class Customers(final List<Customer> all) {
  new demo()
    : this(const [
        .new(
          id: 'acme',
          name: 'Acme Office Supply Sp. z o.o.',
          contact: 'Marta Nowak',
          priceList: 'Acme 2026',
        ),
        .new(
          id: 'northline',
          name: 'Northline Logistics S.A.',
          contact: 'Piotr Zieliński',
          priceList: 'Standard',
        ),
        .new(
          id: 'kowalscy',
          name: 'Kowalscy i Wspólnicy Sp. j.',
          contact: 'Ewa Kowalska',
          priceList: 'Standard',
        ),
      ]);

  /// The customer with [id]; throws an [ArgumentError] for none.
  Customer byId(String id) => all.firstWhere(
    (customer) => customer.id == id,
    orElse: () => throw ArgumentError.value(id, 'customerId', 'is unknown'),
  );
}
