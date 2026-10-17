import 'package:flutter/material.dart';

// The LeanCode palette.
const _black = Color(0xFF0A0A0A);
const _surface = Color(0xFF151513);
const _surfaceRaised = Color(0xFF1D1D1A);
const _hairline = Color.fromRGBO(255, 255, 255, .12);
const _white = Color(0xFFFFFFFF);
const _body = Color(0xFFD8D8D4);
const _muted = Color(0xFFA3A3A0);
const _yellow = Color(0xFFF0FD06);

/// The colour of a done state, such as a placed order.
const success = Color(0xFF80C340);

/// The border of the brand callout, which marks what the agent changed.
const calloutBorder = Color.fromRGBO(240, 253, 6, .5);

/// The wash of the brand callout.
const calloutWash = Color.fromRGBO(240, 253, 6, .06);

/// The corners of a card. Blocks, such as buttons, have none.
const cardCorners = BorderRadius.all(.circular(4));

// The system type. The LeanCode fonts, Switzer and Cabinet Grotesk, are not in
// the repo: their ITF Free Font License forbids sharing them through one.
const _title = TextStyle(fontWeight: .w600);
const _display = TextStyle(fontWeight: .w700);
const _sharp = RoundedRectangleBorder();

/// The LeanCode dark look of the demo: yellow only for emphasis, such as the
/// button that approves, with black text on it.
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
    displaySmall: _display,
    titleLarge: _display,
    titleMedium: _title,
    titleSmall: _title,
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
    style: FilledButton.styleFrom(shape: _sharp),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(foregroundColor: _white, shape: _sharp),
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
