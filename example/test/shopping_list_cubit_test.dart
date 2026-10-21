import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/tandem.dart';

void main() {
  test('remove refuses an item that is not on the list', () {
    final cubit = ShoppingListCubit()..add('bread');
    addTearDown(cubit.close);
    expect(() => cubit.remove('baked goods'), throwsA(isA<ToolCallRefused>()));
    expect(cubit.items, ['bread']);
  });
}
