import 'package:example/desk/desk_order.dart';

/// Where placed orders go.
class Orders() {
  static const _firstNumber = 1042;

  final placed = <DeskOrder>[];

  /// Takes [order] and numbers it.
  Future<OrderId> place(DeskOrder order) async {
    final number = _firstNumber + placed.length;
    placed.add(order);
    return OrderId('ORD-$number');
  }
}
