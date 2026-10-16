import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// Makes an existing `Cubit` or `Bloc` the [StateHost] of the shared state.
/// Nothing to implement:
///
/// ```dart
/// class OrderCubit extends Cubit<OrderState> with AgentEditable<OrderState> {
///   // existing methods unchanged
/// }
/// ```
///
/// A cubit already has the [StateHost.state] and [StateHost.stream] that
/// Tandem reads; the mixin adds [writeFromAgent], which emits the agent's
/// changes like any other state. `BlocBuilder`s, listeners and getters on the
/// state react to them as usual, and the cubit's methods stay unchanged:
/// Tandem tells the user's edits from its own writes by content, so the
/// cubit never has to say who changed the state.
///
/// The agent's changes skip the cubit's methods, so their checks do not run.
/// To limit what the agent may write, check it where the codec builds the
/// state, such as in the `set` of `StateCodec.lens`.
///
/// On a `Bloc`, the agent's changes are emitted directly and bypass the
/// event handlers.
mixin AgentEditable<S> on BlocBase<S> implements StateHost<S> {
  /// Emits [value], a state built from the agent's changes.
  ///
  /// Called by Tandem only, never after its session is disposed. A screen
  /// changes its state through its own methods, as before.
  @override
  void writeFromAgent(S value) => emit(value);
}
