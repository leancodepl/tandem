import 'package:flutter/widgets.dart';
import 'package:tandem/src/genui/agent_catalog.dart';
import 'package:tandem/src/genui/drawn_view.dart';
import 'package:tandem/src/session/session_scope.dart';

/// Where the in-app agent draws a view, with the widgets of [catalog]. Put
/// one below a `TandemScope`: while it is there, every run offers the agent
/// `tandem_show_view`. Tandem checks each view before it draws: its
/// components and properties against the catalog, its paths against what
/// the screen lists with `.sees`, its actions against the methods it lists.
/// A view that does not fit goes back to the agent, one line per problem.
///
/// The view follows the screen: every change of the surface draws it again
/// with the data now. A component whose required value or action is
/// missing now is left out until it is back. An action calls its method for
/// the view, with the session's checks and approvals, one at a time.
///
/// It takes no space before the agent draws, and it does not scroll: wrap
/// it in a scroll view when the view can be taller than its place. A view
/// that cannot show, such as one that grows past 500 components, the items
/// of its lists counted, shows [whenUnavailable] until it can again.
final class const TandemView({
  super.key,
  required final AgentCatalog catalog,
  final WidgetBuilder? whenUnavailable,
}) extends StatefulWidget {
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
    _replaceView();
  }

  @override
  void didUpdateWidget(TandemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog) _replaceView();
  }

  @override
  void dispose() {
    _view?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_view) {
    final view? => ListenableBuilder(
      listenable: view,
      builder: (context, _) =>
          view.build(context, widget.whenUnavailable ?? _unavailable),
    ),
    null => const SizedBox.shrink(),
  };

  void _replaceView() {
    _view?.dispose();
    _view = DrawnView(TandemSessionScope.of(context), widget.catalog);
  }

  static Widget _unavailable(BuildContext context) =>
      const Text('This view is not available now.');
}
