import 'package:example/desk/desk_order.dart';

class Orders() {
  final placed = <DeskOrder>[];

  Future<OrderId> place(DeskOrder order) async {
    final number = 1042 + placed.length;
    placed.add(order);
    return OrderId('ORD-$number');
  }
}
