import 'package:flutter/material.dart';

const _black = Color(0xFF0A0A0A);
const _surface = Color(0xFF151513);
const _surfaceRaised = Color(0xFF1D1D1A);
const _hairline = Color.fromRGBO(255, 255, 255, .12);
const _white = Color(0xFFFFFFFF);
const _body = Color(0xFFD8D8D4);
const _muted = Color(0xFFA3A3A0);
const _yellow = Color(0xFFF0FD06);

const success = Color(0xFF80C340);

const cardCorners = BorderRadius.all(.circular(4));

final deskTheme = ThemeData(
  colorScheme: const .dark(
    primary: _yellow,
    onPrimary: _black,
    primaryContainer: _surfaceRaised,
    surface: _black,
    onSurface: _white,
    onSurfaceVariant: _muted,
    surfaceContainer: _surface,
    surfaceContainerHigh: _surfaceRaised,
    outline: _hairline,
    outlineVariant: _hairline,
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(fontWeight: .w700),
    titleLarge: TextStyle(fontWeight: .w700),
    titleMedium: TextStyle(fontWeight: .w600),
    titleSmall: TextStyle(fontWeight: .w600),
    bodyLarge: TextStyle(color: _body),
    bodyMedium: TextStyle(color: _body),
    bodySmall: TextStyle(color: _muted),
    labelLarge: TextStyle(fontWeight: .w600),
    labelMedium: TextStyle(color: _muted, fontWeight: .w600),
  ),
  cardTheme: const CardThemeData(
    color: _surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: cardCorners,
      side: BorderSide(color: _hairline),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(shape: const RoundedRectangleBorder()),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _white,
      shape: const RoundedRectangleBorder(),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: _white),
  ),
  inputDecorationTheme: const InputDecorationThemeData(
    filled: true,
    fillColor: _surface,
    border: OutlineInputBorder(borderRadius: .zero),
    enabledBorder: OutlineInputBorder(
      borderRadius: .zero,
      borderSide: BorderSide(color: _hairline),
    ),
  ),
);

extension ThemeContext on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
