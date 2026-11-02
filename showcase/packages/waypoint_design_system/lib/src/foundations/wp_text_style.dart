import 'package:flutter/painting.dart';
import 'package:waypoint_design_system/src/foundations/wp_colors.dart';

abstract final class WPTextStyle() {
  static const _sans = 'Barlow';
  static const _condensed = 'Barlow Condensed';
  static const _package = 'waypoint_design_system';
  static const _figures = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 76,
    height: .92,
    letterSpacing: -.5,
    color: WPColors.ink,
  );

  static const headline = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 56,
    height: .92,
    letterSpacing: -.5,
    color: WPColors.ink,
  );

  static const cardTitle = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: .92,
    letterSpacing: -.5,
    color: WPColors.ink,
  );

  static const time = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 30,
    height: 1.05,
    letterSpacing: .3,
    color: WPColors.ink,
    fontFeatures: _figures,
  );

  static const route = TextStyle(
    fontFamily: _condensed,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1,
    letterSpacing: 1,
    color: WPColors.ink,
  );

  static const title = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 1.3,
    color: WPColors.ink,
  );

  static const body = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
    color: WPColors.ink,
    fontFeatures: _figures,
  );

  static const subtitle = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w400,
    fontSize: 17,
    height: 1.45,
    color: WPColors.muted,
    fontFeatures: _figures,
  );

  static const label = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.35,
    color: WPColors.muted,
    fontFeatures: _figures,
  );

  static const day = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 1.1,
    color: WPColors.muted,
  );

  static const button = TextStyle(
    fontFamily: _sans,
    package: _package,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.2,
  );

  static const struck = TextStyle(
    decoration: TextDecoration.lineThrough,
    decorationColor: WPColors.muted,
  );
}
