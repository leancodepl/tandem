import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// Makes the screen below it agent-aware: one [TandemSession] of the [C]
/// provided above it.
///
/// Put it under the `BlocProvider` of [C], with the [TandemChat] below it:
///
/// ```dart
/// BlocProvider(
///   create: (context) => OrderCubit(catalog: catalog, orders: orders),
///   child: TandemScope<OrderCubit>(
///     agent: Uri.parse('https://example.com/agent'),
///     child: Row(
///       children: [
///         Expanded(child: OrderForm()),
///         SizedBox(width: 360, child: TandemChat()),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// Every state that [C] emits once an approval card shows invalidates the
/// card for good, even a state that changes nothing the agent sees (`.sees`).
///
/// An ordinary rebuild keeps the session. A new session replaces the old one
/// when the provider above gives another [C], when `agent` is another [Uri]
/// (compared with `==`), or when `connected` gets another connection
/// (compared with `identical`: keep it in a field, not in `build`). A new
/// [onAgentCall] takes effect at once. A scope that leaves the tree disposes
/// its session before the `BlocProvider` closes [C].
final class TandemScope<C extends AgentSurface> extends StatefulWidget {
  /// A scope that talks to the AG-UI endpoint `agent`.
  const new({
    super.key,
    required Uri this._agent,
    required this.child,
    this.onAgentCall,
  }) : _connection = null;

  /// A scope that talks over `connection`, such as a `ScriptedAgent` in a
  /// test or a client of your own.
  const new connected({
    super.key,
    required AgentConnection this._connection,
    required this.child,
    this.onAgentCall,
  }) : _agent = null;

  final Uri? _agent;
  final AgentConnection? _connection;

  /// The screen, with a [TandemChat] below.
  final Widget child;

  /// Called after every call of a listed method that ran, with a context
  /// below the `BlocProvider` of [C], so it can read the cubit.
  final void Function(BuildContext context, AgentCall call)? onAgentCall;

  @override
  State<TandemScope<C>> createState() => _TandemScopeState();
}

final class _TandemScopeState<C extends AgentSurface>()
    extends State<TandemScope<C>> {
  late C _cubit;
  late TandemSession _session;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<C>();
    _session = _open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cubit = context.read<C>();
    if (!identical(cubit, _cubit)) {
      _cubit = cubit;
      _reopen();
    }
  }

  @override
  void didUpdateWidget(TandemScope<C> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._agent != oldWidget._agent ||
        !identical(widget._connection, oldWidget._connection)) {
      _reopen();
    }
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calls didChangeDependencies for another cubit, not for its states.
    context.select<C, C>((cubit) => cubit);
    return TandemSessionScope(session: _session, child: widget.child);
  }

  void _reopen() {
    _session.dispose();
    _session = _open();
  }

  TandemSession _open() => TandemSession(
    surface: _cubit,
    changes: switch (_cubit) {
      StateStreamable<Object?>(:final stream) => stream,
      _ => throw FlutterError(
        'TandemScope<C> needs C to be a Cubit or Bloc, provided above it.',
      ),
    },
    connection: switch ((widget._connection, widget._agent)) {
      (final connection?, _) => connection,
      (_, final agent?) => HttpAgentConnection(agent),
      _ => throw StateError('A TandemScope has an agent or a connection.'),
    },
    onAgentCall: (call) => widget.onAgentCall?.call(context, call),
  );
}
