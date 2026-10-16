/// Connects Tandem to bloc: the screen's existing `Cubit` or `Bloc` holds
/// the shared state, and a `TandemCubit` holds the session's view.
///
/// The whole integration of a bloc screen is one mixin on its cubit
/// (`AgentEditable`) and one widget on its route (`TandemScope`), plus an
/// `AgentConnection` provided once for the app with
/// `RepositoryProvider<AgentConnection>`.
library;

export 'src/agent_editable.dart' show AgentEditable;
export 'src/tandem_cubit.dart' show TandemCubit;
export 'src/tandem_scope.dart' show TandemScope;
