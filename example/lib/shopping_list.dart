import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem_bloc/tandem_bloc.dart';

part 'shopping_list.g.dart';

class const ShoppingListState({final List<String> items = const []});

class ShoppingListCubit()
    extends Cubit<ShoppingListState>
    with _$ShoppingListCubit {
  this : super(const .new());

  @override
  List<AgentCapability> get agent => [
    .sees(items),
    .calls(add),
    .calls(remove),
    if (items.isNotEmpty) .callsWithApproval(clear),
  ];

  /// What is on the shopping list now.
  List<String> get items => state.items;

  /// Adds [item] to the list.
  void add(String item) => emit(.new(items: [...items, item]));

  /// Removes [item] from the list.
  void remove(String item) => emit(.new(items: [...items]..remove(item)));

  /// Empties the list.
  void clear() => emit(const .new());
}
