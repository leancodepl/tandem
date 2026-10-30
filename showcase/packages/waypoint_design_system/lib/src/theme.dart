import 'package:flutter/material.dart';

/// Waypoint is neutral; the blue marks only what the assistant did.
abstract final class Palette() {
  static const bg = Color(0xFF0D1015);
  static const panel = Color(0xFF11151B);
  static const surface = Color(0xFF151A21);
  static const raised = Color(0xFF1D242D);
  static const line = Color(0xFF232A33);
  static const lineStrong = Color(0xFF353E4A);
  static const ink = Color(0xFFF1EEE8);
  static const muted = Color(0xFF98A0AA);

  /// Tandem's blue, the site's accent: the assistant's marks.
  static const ai = Color(0xFF0187FD);

  /// The border of a card the assistant changed: [line] 70 % of the way to
  /// [ai].
  static const aiLine = Color(0xFF0B6BC0);

  /// The assistant's blue for text on the dark surfaces.
  static const aiText = Color(0xFF4AA8FF);
  static const warn = Color(0xFFE5A94A);

  /// What dims the screen behind a sheet.
  static const scrim = Color(0xB3000000);
}

abstract final class Radii() {
  static const card = BorderRadius.all(Radius.circular(10));
  static const control = BorderRadius.all(Radius.circular(10));

  /// The corners of a sheet, a dialog and the assistant's dock.
  static const sheet = Radius.circular(16);
}

abstract final class AppText() {
  static const _sans = 'Barlow';
  static const _condensed = 'Barlow Condensed';
  static const _package = 'waypoint_design_system';
  static const _figures = [FontFeature.tabularFigures()];

  /// The city, in capitals.
  static const display = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 76,
    height: .92,
    letterSpacing: -.5,
    color: Palette.ink,
  );

  /// A page's title, and the city of a trip on a phone.
  static const headline = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 56,
    height: .92,
    letterSpacing: -.5,
    color: Palette.ink,
  );

  /// The title of a card in a list, such as a trip's city.
  static const cardTitle = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: .92,
    letterSpacing: -.5,
    color: Palette.ink,
  );

  /// Departure and arrival times.
  static const time = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 30,
    height: 1.05,
    letterSpacing: .3,
    color: Palette.ink,
    fontFeatures: _figures,
  );

  static const route = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1,
    letterSpacing: 1,
    color: Palette.ink,
  );

  static const title = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 1.3,
    color: Palette.ink,
  );

  static const body = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
    color: Palette.ink,
    fontFeatures: _figures,
  );

  /// What follows a title, such as a trip's dates.
  static const subtitle = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 17,
    height: 1.45,
    color: Palette.muted,
    fontFeatures: _figures,
  );

  static const label = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.35,
    color: Palette.muted,
    fontFeatures: _figures,
  );

  /// Day headers: the one place with capitals and tracking.
  static const day = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 1.1,
    color: Palette.muted,
  );

  static const button = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.2,
  );

  /// What no longer holds, merged onto another style.
  static const struck = TextStyle(
    decoration: TextDecoration.lineThrough,
    decorationColor: Palette.muted,
  );
}

ThemeData waypointTheme() {
  const scheme = ColorScheme.dark(
    surface: Palette.bg,
    onSurface: Palette.ink,
    primary: Palette.ink,
    onPrimary: Palette.bg,
    secondary: Palette.ai,
    outline: Palette.lineStrong,
    outlineVariant: Palette.line,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    fontFamily: 'Barlow',
    package: 'waypoint_design_system',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Palette.raised,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.panel,
      indicatorColor: Palette.raised,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppText.label.copyWith(
          color: states.contains(WidgetState.selected)
              ? Palette.ink
              : Palette.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Palette.ink
              : Palette.muted,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Palette.panel,
      indicatorColor: Palette.raised,
      selectedIconTheme: IconThemeData(color: Palette.ink),
      unselectedIconTheme: IconThemeData(color: Palette.muted),
      selectedLabelTextStyle: TextStyle(color: Palette.ink),
      unselectedLabelTextStyle: TextStyle(color: Palette.muted),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Palette.panel,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radii.sheet),
      ),
      headerForegroundColor: Palette.ink,
      headerHelpStyle: AppText.label,
      headerHeadlineStyle: AppText.title,
      weekdayStyle: AppText.label,
      dayStyle: AppText.body,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Palette.bg;
        if (states.contains(WidgetState.disabled)) return Palette.muted;
        return Palette.ink;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Palette.ink : null,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Palette.bg : Palette.ink,
      ),
      todayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Palette.ink : null,
      ),
      todayBorder: const BorderSide(color: Palette.lineStrong),
      yearStyle: AppText.body,
      dividerColor: Palette.line,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        textStyle: AppText.button,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        textStyle: AppText.button,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Palette.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radii.sheet),
      ),
      helpTextStyle: AppText.label,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.ink
            : Palette.raised,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Palette.bg : Palette.ink,
      ),
      dialBackgroundColor: Palette.raised,
      dialHandColor: Palette.ink,
      dialTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Palette.bg : Palette.ink,
      ),
      entryModeIconColor: Palette.muted,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        textStyle: AppText.button,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        textStyle: AppText.button,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.ai,
      selectionColor: Color(0x550187FD),
      selectionHandleColor: Palette.ai,
    ),
    textTheme: const TextTheme(bodyMedium: AppText.body),
  );
}
