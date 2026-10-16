import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem_bloc/src/tandem_cubit.dart';

/// Makes the screen below agent-aware: creates a [TandemSession] for the
/// state host [C] found above it and provides a [TandemCubit] below it.
///
/// Put it under the `BlocProvider` of [C]:
///
/// ```dart
/// BlocProvider(
///   create: (context) => OrderCubit(),
///   child: TandemScope<OrderCubit, OrderState>(
///     codec: StateCodec.lens(
///       'order',
///       get: (state) => state.draft,
///       set: (state, draft) => state.copyWith(draft: draft),
///       fromJson: OrderDraft.fromJson,
///       toJson: (draft) => draft.toJson(),
///     ),
///     tools: (context) => [
///       Tool('place_order', 'Place the order exactly as it is on the screen.',
///           needsApproval: true,
///           run: (call) => context.read<Orders>().place(call.state.draft)),
///     ],
///     child: const OrderScreen(),
///   ),
/// )
/// ```
///
/// The screen then reads the view with `context.watch<TandemCubit>().state`
/// and sends messages with `context.read<TandemCubit>().send(text)`.
///
/// The session is created when the scope is first built, and everything it
/// needs is read then, once: [codec], [tools], [options], the connection and
/// the host. A later rebuild with other values keeps the session; give the
/// scope a new `key` to start a new one. When the scope leaves the tree, the
/// session is disposed before the `BlocProvider` above closes [C], so the
/// agent never writes into a closed cubit.
class TandemScope<C extends StateHost<S>, S> extends StatelessWidget {
  /// Creates the scope.
  const TandemScope({
    super.key,
    required this.codec,
    required this.child,
    this.tools,
    this.connection,
    this.options = const TandemOptions(),
  });

  /// How the shared state of [C] is shown to the agent.
  final StateCodec<S> codec;

  /// The screen's tools: functions of the app the agent may call.
  ///
  /// Called once, when the session is created, with a context inside this
  /// scope, so a tool can read the repositories and cubits above it:
  /// `run: (call) => context.read<Catalog>().search(call.read('query'))`.
  ///
  /// A tool that is still running when the screen closes runs to its end,
  /// and its result is dropped. If it changes a cubit afterwards, it should
  /// check the cubit's `isClosed` first.
  final List<Tool<S>> Function(BuildContext context)? tools;

  /// The connection to the agent backend.
  ///
  /// Defaults to the [AgentConnection] provided above, usually once for the
  /// whole app with `RepositoryProvider<AgentConnection>`. Without a
  /// connection, the scope fails with a message that says how to provide
  /// one.
  final AgentConnection? connection;

  /// Everything optional about the session, such as the labels of the
  /// agent's tools and the loop guard.
  final TandemOptions options;

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A missing connection or host fails here, in debug builds, with a
    // message that says how to fix it. Inside the provider's create below,
    // the provider would report it as a value that threw while it was being
    // created.
    assert(() {
      _connectionOf(context);
      _hostOf(context);
      return true;
    }());
    return BlocProvider<TandemCubit>(
      lazy: false,
      create: _createCubit,
      child: child,
    );
  }

  TandemCubit _createCubit(BuildContext context) => TandemCubit(
    TandemSession<S>(
      connection: _connectionOf(context),
      host: _hostOf(context),
      codec: codec,
      tools: tools?.call(context) ?? const [],
      options: options,
    ),
  );

  AgentConnection _connectionOf(BuildContext context) =>
      connection ??
      _read<AgentConnection>(
        context,
        () => FlutterError.fromParts([
          ErrorSummary(
            'TandemScope<$C, $S> found no AgentConnection. Provide one above '
            'it with RepositoryProvider<AgentConnection>, or pass '
            'TandemScope.connection.',
          ),
          ErrorDescription(
            'The scope sends the runs of its session to the agent backend '
            'through an AgentConnection. Its connection parameter is null, '
            'so it looked for an AgentConnection provided above it and found '
            'none.',
          ),
          ErrorHint(
            'Provide the connection once for the whole app, with the type '
            'argument, so it is found as an AgentConnection:\n'
            '\n'
            '  RepositoryProvider<AgentConnection>(\n'
            '    create: (context) => AgentConnection.http(Uri.parse(...)),\n'
            '    child: MyApp(),\n'
            '  )\n'
            '\n'
            'Without the type argument, '
            'RepositoryProvider.value(value: ScriptedAgent(...)) provides a '
            'ScriptedAgent, and the scope does not find it.',
          ),
        ]),
      );

  C _hostOf(BuildContext context) => _read<C>(
    context,
    () => FlutterError.fromParts([
      ErrorSummary(
        'TandemScope<$C, $S> found no $C above it. Put it under the '
        'BlocProvider<$C> that creates the cubit.',
      ),
      ErrorDescription(
        'The shared state lives in the $C of the screen, and the scope '
        'attaches its session to it.',
      ),
    ]),
  );

  /// The [T] provided above [context], or the error [missing] builds when
  /// there is none.
  static T _read<T>(BuildContext context, FlutterError Function() missing) {
    try {
      return context.read<T>();
    } on ProviderNotFoundException catch (e) {
      // Only when T itself is missing, not something its provider needs.
      if (e.valueType != T) {
        rethrow;
      }
      throw missing();
    }
  }
}
