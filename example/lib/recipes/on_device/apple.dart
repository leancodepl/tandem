import 'package:example/shopping_list/shopping_list.dart';
import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

void main() => runApp(
  MaterialApp(home: ShoppingListScreen(connection: OnDeviceAgent.apple())),
);
