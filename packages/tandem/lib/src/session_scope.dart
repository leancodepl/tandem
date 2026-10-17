import 'package:flutter/widgets.dart';
import 'package:tandem/src/session.dart';

const _missingScope =
    'No TandemScope found above this context. TandemChat needs the screen to '
    'be wrapped in a TandemScope.';

/// Gives the widgets below it the [TandemSession] of their screen, and
/// rebuilds the ones that read it when it changes.
///
/// The `TandemScope` of an adapter package such as `tandem_bloc` builds this;
/// apps do not use it.
final class const TandemSessionScope({
  super.key,
  required TandemSession session,
  required super.child,
}) extends InheritedNotifier<TandemSession> {
  /// Provides [session] to [child].
  this : super(notifier: session);

  /// The session of the closest scope above [context].
  ///
  /// Throws a [FlutterError] when there is none.
  static TandemSession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TandemSessionScope>();
    if (scope?.notifier case final session?) {
      return session;
    }
    throw FlutterError(_missingScope);
  }
}
