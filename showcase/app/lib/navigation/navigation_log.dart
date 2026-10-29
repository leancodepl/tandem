import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

final _log = Logger('Navigation');

/// Logs the pages the traveller opens and leaves, by name, and the tabs.
/// Sheets have no name, and their processes log themselves.
final class NavigationLog() extends AutoRouterObserver {
  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    if (route.settings.name case final name?) _log.info('Opened $name');
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    if (route.settings.name case final name?) _log.info('Left $name');
  }

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    if (newRoute?.settings.name case final name?) _log.info('Opened $name');
  }

  @override
  void didInitTabRoute(TabPageRoute route, TabPageRoute? previousRoute) =>
      _log.info('Opened the tab ${route.name}');

  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) =>
      _log.info('Opened the tab ${route.name}');
}
