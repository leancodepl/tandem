import 'package:example/desk/ui/order_desk_app.dart';
import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

void main() {
  TandemBridge.enable();
  runApp(const OrderDeskApp());
}
