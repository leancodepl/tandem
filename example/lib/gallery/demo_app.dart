import 'package:example/desk/ui/desk_theme.dart';
import 'package:example/gallery/gallery_screen.dart';
import 'package:flutter/material.dart';

final class const DemoApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tandem examples',
    debugShowCheckedModeBanner: false,
    theme: deskTheme,
    home: const GalleryScreen(),
  );
}
