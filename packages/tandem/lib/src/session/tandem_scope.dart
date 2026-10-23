import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/debug/open_screens.dart';
import 'package:tandem/src/protocol/ag_ui.dart';
import 'package:tandem/src/protocol/agent_connection.dart';
import 'package:tandem/src/session/approvals.dart';
import 'package:tandem/src/session/session_scope.dart';
import 'package:tandem/src/session/tandem_event.dart';
import 'package:tandem/src/session/tandem_session.dart';

/// Makes the screen below it agent-aware: one [TandemSession] of the object
/// that [surface] gives.
///
/// Put it below whatever owns that object, with the screen and the app's
/// chat below it. The chat reads the session with [TandemSessionScope.of].
/// With bloc:
///
/// ```dart
/// BlocProvider(
///   create: (_) => OrderCubit(catalog: catalog, orders: orders),
///   child: TandemScope(
///     surface: (context) => context.read<OrderCubit>(),
///     agent: Uri.parse('https://example.com/agent'),
///     approvals: const .fromState(),
///     child: const Row(
///       children: [
///         Expanded(child: OrderForm()),
///         SizedBox(width: 360, child: AgentChat()),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// An ordinary rebuild keeps the session. A new session replaces the old one
/// when `agent` is another [Uri] (compared with `==`), or when `connected`
/// gets another connection (compared with `identical`: keep it in a field,
/// not in `build`). A new [onEvent] or [approvals] takes effect at once. A
/// scope that leaves the tree disposes its session before an ancestor that
/// owns the surface closes it.
final class TandemScope extends StatefulWidget {
  /// A scope that talks to the AG-UI endpoint `agent`. Without one, only a
  /// coding agent drives the screen, through `TandemBridge`, and a run of
  /// `session.send` fails.
  const new({
    super.key,
    required this.surface,
    this._agent,
    required this.approvals,
    required this.child,
    this.onEvent,
  }) : _connection = null;

  /// A scope that talks over `connection`, such as `OnDeviceAgent.apple()`,
  /// a `ScriptedAgent` in a test or a client of your own.
  const new connected({
    super.key,
    required this.surface,
    required AgentConnection this._connection,
    required this.approvals,
    required this.child,
    this.onEvent,
  }) : _agent = null;

  /// Reads the object the agent works on, a class with `@TandemAgent()`,
  /// from the context of this scope. The scope calls it when it opens a
  /// session: once, and again for another `agent` or connection. Another
  /// object from the provider later opens no new session.
  final AgentSurface Function(BuildContext context) surface;

  final Uri? _agent;
  final AgentConnection? _connection;

  /// How the screen asks the user to approve a call of a method listed
  /// with `.callsWithApproval`.
  final TandemApprovals approvals;

  /// The screen and its chat, which read the session with
  /// [TandemSessionScope.of].
  final Widget child;

  /// Hears what happens in the session, with the context of this scope, so
  /// it can read what is provided above it, and the session, which is below
  /// it.
  final void Function(
    BuildContext context,
    TandemEvent event,
    TandemSession session,
  )?
  onEvent;

  @override
  State<TandemScope> createState() => _TandemScopeState();
}

final class _TandemScopeState() extends State<TandemScope> {
  late TandemSession _session;
  late final OpenScreen _openScreen;

  @override
  void initState() {
    super.initState();
    _session = _open();
    if (kDebugMode) {
      _openScreen = OpenScreens.open(context, () => _session);
    }
  }

  @override
  void didUpdateWidget(TandemScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._agent != oldWidget._agent ||
        !identical(widget._connection, oldWidget._connection)) {
      _session.dispose();
      _session = _open();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      OpenScreens.close(_openScreen);
    }
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TandemSessionScope(session: _session, child: widget.child);

  TandemSession _open() {
    late final TandemSession session;
    return session = TandemSession(
      surface: widget.surface(context),
      connection: switch ((widget._connection, widget._agent)) {
        (final connection?, _) => connection,
        (_, final agent?) => HttpAgentConnection(agent),
        _ => const _NoAgent(),
      },
      onEvent: (event) => widget.onEvent?.call(context, event, session),
      onApprovalRequest: (request) async {
        if (widget.approvals case ApprovalsByCallback(:final callback)) {
          await callback(context, request, session);
        }
      },
      asksForApproval: () => widget.approvals is! NoApprovals,
    );
  }
}

/// The connection of a scope without `agent`: every run fails and says so.
final class const _NoAgent() implements AgentConnection {
  @override
  Stream<JsonObject> run(JsonObject input) => Stream.value({
    AgUiFields.type: AgUiEventTypes.runError,
    AgUiFields.message:
        'This TandemScope has no agent. Give it agent: or use '
        'TandemScope.connected to send messages.',
  });
}
