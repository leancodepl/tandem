import 'package:flutter/widgets.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// Gives the widgets below it the [TandemSession] of the screen. The
/// `TandemScope` of an adapter package such as `tandem_bloc` builds it.
final class const TandemSessionScope({
  super.key,
  required TandemSession session,
  required super.child,
}) extends InheritedNotifier<TandemSession> {
  this : super(notifier: session);

  /// The session an app's chat shows and drives. A widget that calls it
  /// rebuilds whenever the session changes. Throws a [FlutterError] when no
  /// scope is above [context].
  static TandemSession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TandemSessionScope>();
    if (scope?.notifier case final session?) {
      return session;
    }
    throw FlutterError(
      'No TandemScope found above this context. Wrap the screen and its chat '
      'in a TandemScope.',
    );
  }
}
