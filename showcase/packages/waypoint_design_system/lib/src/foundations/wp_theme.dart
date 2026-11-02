import 'package:flutter/material.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';
import 'package:waypoint_design_system/src/foundations/wp_radii.dart';
import 'package:waypoint_design_system/src/foundations/wp_text_style.dart';

ThemeData wpTheme() {
  const scheme = ColorScheme.dark(
    surface: WPColors.bg,
    onSurface: WPColors.ink,
    primary: WPColors.ink,
    onPrimary: WPColors.bg,
    secondary: WPColors.ai,
    outline: WPColors.lineStrong,
    outlineVariant: WPColors.line,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: WPColors.bg,
    fontFamily: 'Barlow',
    package: 'waypoint_design_system',
    splashFactory: NoSplash.splashFactory,
    highlightColor: WPColors.raised,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: WPColors.panel,
      indicatorColor: WPColors.raised,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => WPTextStyle.label.copyWith(
          color: states.contains(WidgetState.selected)
              ? WPColors.ink
              : WPColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? WPColors.ink
              : WPColors.muted,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: WPColors.panel,
      indicatorColor: WPColors.raised,
      selectedIconTheme: IconThemeData(color: WPColors.ink),
      unselectedIconTheme: IconThemeData(color: WPColors.muted),
      selectedLabelTextStyle: TextStyle(color: WPColors.ink),
      unselectedLabelTextStyle: TextStyle(color: WPColors.muted),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: WPColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(WPRadii.sheet),
      ),
      headerForegroundColor: WPColors.ink,
      headerHelpStyle: WPTextStyle.label,
      headerHeadlineStyle: WPTextStyle.title,
      weekdayStyle: WPTextStyle.label,
      dayStyle: WPTextStyle.body,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return WPColors.bg;
        if (states.contains(WidgetState.disabled)) return WPColors.muted;
        return WPColors.ink;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? WPColors.ink : null,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? WPColors.bg : WPColors.ink,
      ),
      todayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? WPColors.ink : null,
      ),
      todayBorder: const BorderSide(color: WPColors.lineStrong),
      yearStyle: WPTextStyle.body,
      dividerColor: WPColors.line,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: WPColors.ink,
        textStyle: WPTextStyle.button,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: WPColors.ink,
        textStyle: WPTextStyle.button,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: WPColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(WPRadii.sheet),
      ),
      helpTextStyle: WPTextStyle.label,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? WPColors.ink
            : WPColors.raised,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? WPColors.bg : WPColors.ink,
      ),
      dialBackgroundColor: WPColors.raised,
      dialHandColor: WPColors.ink,
      dialTextColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? WPColors.bg : WPColors.ink,
      ),
      entryModeIconColor: WPColors.muted,
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: WPColors.ink,
        textStyle: WPTextStyle.button,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: WPColors.ink,
        textStyle: WPTextStyle.button,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: WPColors.ai,
      selectionColor: Color(0x550187FD),
      selectionHandleColor: WPColors.ai,
    ),
    textTheme: const TextTheme(bodyMedium: WPTextStyle.body),
  );
}
