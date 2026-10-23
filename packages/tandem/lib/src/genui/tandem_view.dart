import 'package:flutter/material.dart';
import 'package:tandem/src/genui/drawn_view.dart';
import 'package:tandem/src/genui/view_widgets.dart';
import 'package:tandem/src/session/session_scope.dart';

/// Shows a view the in-app agent draws for the user: texts, columns, rows,
/// lists, cards, dividers and buttons, which show only what the screen lists
/// with `.sees`.
///
/// Put it below a `TandemScope`. While it is there, every run offers the
/// agent the tool `show_view`, whose description teaches it these
/// components in A2UI v0.9.1. Each call replaces the whole view, and a call
/// that does not fit the screen is refused with what to fix. Drawing needs
/// a strong model behind an AG-UI backend, not the model on the device.
///
/// The view has no texts of its own and takes no space before the agent
/// draws. It scrolls when it is taller than its space. A new session of the
/// scope starts with an empty view.
final class const TandemView({super.key}) extends StatefulWidget {
  @override
  State<TandemView> createState() => _TandemViewState();
}

final class _TandemViewState() extends State<TandemView> {
  DrawnView? _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = TandemSessionScope.of(context);
    if (_view case final view? when identical(view.session, session)) {
      return;
    }
    _view?.dispose();
    _view = DrawnView(session);
  }

  @override
  void dispose() {
    _view?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_view) {
    final view? => ValueListenableBuilder(
      valueListenable: view.surface,
      builder: (context, surface, _) => switch (surface) {
        final surface? => SingleChildScrollView(child: DrawnSurface(surface)),
        null => const SizedBox.shrink(),
      },
    ),
    null => const SizedBox.shrink(),
  };
}
