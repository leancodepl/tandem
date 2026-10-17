import 'package:flutter/widgets.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// The `TandemScope` of an adapter package such as `tandem_bloc` builds this;
/// apps do not use it.
final class const TandemSessionScope({
  super.key,
  required TandemSession session,
  required super.child,
}) extends InheritedNotifier<TandemSession> {
  this : super(notifier: session);

  /// Throws a [FlutterError] when no scope is above [context].
  static TandemSession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TandemSessionScope>();
    if (scope?.notifier case final session?) {
      return session;
    }
    throw FlutterError(
      'No TandemScope found above this context. TandemChat needs the screen to '
      'be wrapped in a TandemScope.',
    );
  }
}
