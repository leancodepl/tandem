import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/src/session/sees_snapshot.dart';

import '../support/shop.dart';

void main() {
  late Shop shop;
  late List<Object> reported;

  setUp(() {
    shop = Shop();
    addTearDown(shop.close);
    reported = [];
  });

  SeesSnapshot read() =>
      SeesSnapshot.read(shop, report: (err, _) => reported.add(err));

  test('two reads of the same .sees are equal', () {
    shop.add('milk');

    expect(read(), read());
    expect(reported, isEmpty);
  });

  test('a .sees that cannot be read is reported and equals no other '
      'snapshot', () {
    shop.listThrows = true;

    final unreadable = read();

    expect(unreadable, isNot(read()));
    expect(reported, [isStateError, isStateError]);
  });
}
