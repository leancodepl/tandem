import 'package:example/gallery/demo_app.dart';
import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

void main() {
  TandemBridge.enable();
  runApp(const DemoApp());
}
