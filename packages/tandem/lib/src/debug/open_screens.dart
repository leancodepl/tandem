import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/session/sees_snapshot.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// A `TandemScope` of a debug build, which a coding agent reaches through
/// `TandemBridge`.
final class OpenScreen._(
  final ScreenId id,
  final BuildContext _context,
  final TandemSession Function() _session,
) {
  static const _keptContexts = 32;

  /// What `TandemBridge.describe` showed of this screen, by context, oldest
  /// first.
  final _described = <ContextId, DescribedScreen>{};

  /// The scope's session now: another `agent` replaces it.
  TandemSession get session => _session();

  /// Whether the scope is on the current route. A scope outside any route
  /// counts as on it.
  bool get isOnCurrentRoute => ModalRoute.isCurrentOf(_context) ?? true;

  /// The context for [listing], which `TandemBridge.describe` read from
  /// [session]: the newest one when it saw the same, else a new one.
  ContextId contextFor(TandemSession session, AgentListing listing) {
    final sees = SeesSnapshot.of(listing);
    if (_described.entries.lastOrNull case MapEntry(:final key, :final value)
        when identical(value.session, session) && value.sees == sees) {
      return key;
    }
    final context = ContextId('context-${++OpenScreens._lastContext}');
    _described[context] = (
      screen: this,
      session: session,
      seen: listing,
      sees: sees,
    );
    if (_described.length > _keptContexts) {
      _described.remove(_described.keys.first);
    }
    return context;
  }
}

/// What `TandemBridge.describe` showed of a screen, read from its session.
typedef DescribedScreen = ({
  OpenScreen screen,
  TandemSession session,
  AgentListing seen,
  SeesSnapshot sees,
});

/// The open screens of a debug build, oldest first.
final class OpenScreens._() {
  static final _screens = <OpenScreen>[];
  static var _lastContext = 0;

  static List<OpenScreen> get all => UnmodifiableListView([
    for (final screen in _screens)
      if (screen.session.isActive) screen,
  ]);

  /// The only open screen, or else the only one on the current route.
  static OpenScreen? get front => switch (all) {
    [final only] => only,
    final screens =>
      screens.where((screen) => screen.isOnCurrentRoute).singleOrNull,
  };

  static OpenScreen open(
    BuildContext context,
    TandemSession Function() session,
  ) {
    final name = '${session().surface.runtimeType}';
    var id = ScreenId(name);
    for (var number = 2; _screens.any((screen) => screen.id == id); number++) {
      id = ScreenId('$name#$number');
    }
    final screen = OpenScreen._(id, context, session);
    _screens.add(screen);
    return screen;
  }

  static void close(OpenScreen screen) => _screens.remove(screen);

  /// What the open screen that gave [context] showed with it, or null when
  /// no open screen keeps it.
  static DescribedScreen? described(ContextId context) =>
      _screens.map((screen) => screen._described[context]).nonNulls.firstOrNull;

  static OpenScreen? find(ScreenId id) =>
      all.where((screen) => screen.id == id).singleOrNull;

  /// Why there is no open screen with [id] or, without one, no front screen,
  /// for the coding agent.
  static String whyNotFound(ScreenId? id) {
    final screens = all;
    if (screens.isEmpty) {
      return 'No screen with a TandemScope is open.';
    }
    final ids = screens.map((screen) => screen.id).join(', ');
    final current = screens.where((screen) => screen.isOnCurrentRoute);
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
}

/// The id of an open screen: the class name of its surface, numbered when
/// another open screen has it: `Shop`, `Shop#2`.
extension type const ScreenId(String value);

/// The id of what `TandemBridge.describe` showed of a screen, such as
/// `context-7`, which a call passes back so that its paths read that.
extension type const ContextId(String value);
