import 'package:tandem/tandem.dart';

class const Customer({
  required final String id,
  required final String name,
  required final String contact,
  required final String priceList,
});

class Customers(final List<Customer> all) {
  Customer byId(String id) => all.firstWhere(
    (customer) => customer.id == id,
    orElse: () => throw ToolCallRefused('No customer has the id $id.'),
  );
}
