import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const invoiceInk = Color(0xFF1C1C1E);
const invoiceMuted = Color(0xFF8E8E93);
const invoicePaper = Colors.white;
const invoiceBlue = Color(0xFF007AFF);
const invoiceLine = Color(0xFFECECEE);

final invoiceTheme = ThemeData(
  fontFamily: switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'CupertinoSystemText',
    TargetPlatform.macOS => '.AppleSystemUIFont',
    _ => null,
  },
  scaffoldBackgroundColor: invoicePaper,
  colorScheme: const ColorScheme.light(
    primary: invoiceBlue,
    secondary: invoiceBlue,
    onSurface: invoiceInk,
    onSurfaceVariant: invoiceMuted,
    outline: invoiceLine,
  ),
  splashFactory: NoSplash.splashFactory,
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: invoiceBlue,
    selectionColor: Color(0x33007AFF),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: .circular(13)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: .w600),
    ),
  ),
);
