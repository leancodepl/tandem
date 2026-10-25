import 'package:flutter/widgets.dart';
import 'package:tandem/src/genui/drawn_view.dart';
import 'package:tandem/src/genui/view_widgets.dart';
import 'package:tandem/src/session/session_scope.dart';

/// Shows what the in-app agent draws for the user: texts, columns, rows,
/// lists, cards, dividers and buttons. The texts show only what the screen
/// lists with `.sees`, and a button calls a method the screen lists.
///
/// Put it below a `TandemScope`, one per screen. While it is there, every
/// run offers the agent the tool `tandem_show_view`, whose description teaches it
/// these components in A2UI. Each call replaces the whole view, and a call
/// that does not fit the screen is refused with what to fix. Drawing needs
/// a strong model behind an AG-UI backend, not a small model on the device.
///
/// The view has no texts of its own, takes no space before the agent draws
/// and does not scroll: give it a scroll view when it can be taller than
/// its space. A new session of the scope starts with an empty view.
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
