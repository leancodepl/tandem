import 'package:flutter/widgets.dart';
import 'package:tandem/src/genui/drawn_view.dart';
import 'package:tandem/src/genui/view_widgets.dart';
import 'package:tandem/src/session/session_scope.dart';

/// Renders the in-app agent's A2UI view with Tandem's fixed component catalog.
/// Data bindings read values listed with `.sees`. Literal text is allowed.
/// Buttons call listed methods with the session's checks and approvals.
///
/// Put one below a `TandemScope`, where the drawn view should appear.
/// Attaching it makes `tandem_show_view` available to the agent. An accepted
/// call replaces the view after the run finishes. Invalid views return an
/// explanation to the agent. Use a strong model through an AG-UI backend.
///
/// The widget takes no space before a view arrives and does not scroll.
/// Wrap it in a scroll view when the content may exceed its space.
/// A new session starts with an empty view.
final class const TandemView({super.key}) extends StatefulWidget {
  @override
  State<TandemView> createState() => _TandemViewState();
}

final class _TandemViewState() extends State<TandemView> {
  DrawnView? _view;

  /// Kept while the view stays, so that a change of the session rebuilds
  /// only what depends on it.
  late Widget _content;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = TandemSessionScope.of(context);
    if (_view case final view? when identical(view.session, session)) {
      return;
    }
    _view?.dispose();
    final view = _view = DrawnView(session);
    _content = ValueListenableBuilder(
      valueListenable: view.surface,
      builder: (context, surface, _) => switch (surface) {
        final surface? => DrawnSurface(view, surface),
        null => const SizedBox.shrink(),
      },
    );
  }

  @override
  void dispose() {
    _view?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _content;
}
