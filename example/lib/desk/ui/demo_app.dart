import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/desk/ui/order_desk_screen.dart';
import 'package:flutter/material.dart';

/// The order desk in the LeanCode dark look, talking to the agent at
/// `localhost:8000`.
final class const DemoApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tandem demo',
    debugShowCheckedModeBanner: false,
    theme: deskTheme,
    home: const OrderDeskScreen(),
  );
}
