import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

const _notStreamable =
    'TandemScope<C> needs C to be a Cubit or Bloc, provided above it.';

/// Makes the screen below it agent-aware: one [TandemSession] of the [C]
/// provided above it, for as long as the scope lives.
///
/// Put it under the `BlocProvider` of [C], with the [TandemChat] below it:
///
/// ```dart
/// BlocProvider(
///   create: (context) => OrderCubit(catalog: catalog, orders: orders),
///   child: TandemScope<OrderCubit>(
///     agent: Uri.parse('https://example.com/agent'),
///     child: Row(children: [OrderForm(), TandemChat()]),
///   ),
/// )
/// ```
///
/// When what the agent sees (`.sees`) changes, the approvals still pending
/// are invalidated. The session is created once, so the conversation is one
/// AG-UI thread, and it is disposed before the `BlocProvider` closes [C].
final class TandemScope<C extends AgentSurface> extends StatefulWidget {
  /// A scope that talks to the AG-UI endpoint `agent`. [onAgentCall] hears
  /// every call of a listed method that ran.
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

  /// The screen.
  final Widget child;

  /// Called after every call of a listed method that ran.
  final AgentCallListener? onAgentCall;

  @override
  State<TandemScope<C>> createState() => _TandemScopeState();
}

final class _TandemScopeState<C extends AgentSurface>()
    extends State<TandemScope<C>> {
  late final TandemSession _session;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<C>();
    _session = TandemSession(
      surface: cubit,
      changes: switch (cubit) {
        StateStreamable<Object?>(:final stream) => stream,
        _ => throw FlutterError(_notStreamable),
      },
      connection: widget._connection ?? HttpAgentConnection(widget._agent!),
      onAgentCall: widget.onAgentCall,
    );
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TandemSessionScope(session: _session, child: widget.child);
}
