import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// A `TandemScope` of a debug build, which a coding agent reaches through
/// `TandemBridge`.
final class OpenScreen._(
  /// The class name of the scope's surface, numbered when another open
  /// screen has it: `Shop`, `Shop#2`.
  final String id,
  final BuildContext _context,
  final TandemSession Function() _session,
) {
  /// The scope's session now: another `agent` replaces it.
  TandemSession get session => _session();

  /// Whether the scope is on the current route. A scope outside any route
  /// counts as on it.
  bool get isOnCurrentRoute => ModalRoute.isCurrentOf(_context) ?? true;
}

/// The open screens of a debug build, oldest first.
final class OpenScreens._() {
  static final _screens = <OpenScreen>[];

  static List<OpenScreen> get all => UnmodifiableListView(_screens);

  /// The only open screen, or else the only one on the current route.
  static OpenScreen? get front => switch (_screens) {
    [final only] => only,
    _ => _screens.where((screen) => screen.isOnCurrentRoute).singleOrNull,
  };

  static OpenScreen open(
    BuildContext context,
    TandemSession Function() session,
  ) {
    final name = '${session().surface.runtimeType}';
    var id = name;
    for (var number = 2; _find(id) != null; number++) {
      id = '$name#$number';
    }
    final screen = OpenScreen._(id, context, session);
    _screens.add(screen);
    return screen;
  }

  static void close(OpenScreen screen) => _screens.remove(screen);

  /// The open screen with [id] or, without one, the front screen.
  static OpenScreen? find(String? id) => switch (id) {
    final id? => _find(id),
    null => front,
  };

  /// Why [find] finds no screen for [id], for the coding agent.
  static String whyNotFound(String? id) {
    if (_screens.isEmpty) {
      return 'No screen with a TandemScope is open.';
    }
    final ids = _screens.map((screen) => screen.id).join(', ');
    final current = _screens.where((screen) => screen.isOnCurrentRoute);
    return switch (id) {
      final id? => 'No open screen has the id $id. Pass screen, one of: $ids.',
      null when current.isEmpty =>
        'Several screens are open and none is in front. Pass screen, one '
            'of: $ids.',
      null =>
        'Several screens are on the current route, as tabs or side by side. '
            'Pass screen, one of: $ids.',
    };
  }

  static OpenScreen? _find(String id) =>
      _screens.where((screen) => screen.id == id).singleOrNull;
}
