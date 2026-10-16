import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tandem/tandem.dart';

/// The view of one [TandemSession] as a `Cubit`: its state is the session's
/// current [TandemView], with a new one after every change.
///
/// It is not generic, so the screen reads it without type arguments:
///
/// ```dart
/// final view = context.watch<TandemCubit>().state;
/// ```
///
/// `TandemScope` creates and provides it. Approvals and retries need no
/// method here: they are actions on the items of the view, such as
/// [ApprovalRequest.approve] and [TandemError.retry].
class TandemCubit extends Cubit<TandemView> {
  /// Mirrors [session], starting with its current view.
  ///
  /// The cubit owns the session from now on: [close] disposes it.
  TandemCubit(this.session) : super(session.view) {
    _views = session.views.listen(emit);
  }

  /// The session behind this cubit, for code outside the widget tree.
  final TandemSession<Object?> session;

  late final StreamSubscription<TandemView> _views;

  /// Sends a user message and runs the agent. See [TandemSession.send].
  Future<void> send(String text) => session.send(text);

  /// Cancels the current run and any automatic follow-up. See
  /// [TandemSession.stop].
  Future<void> stop() => session.stop();

  /// Disposes the session before anything else, then closes the cubit.
  ///
  /// The session stops writing into its state host during the call, before
  /// the returned future completes, so the host may be closed right after
  /// it, as a parent `BlocProvider` does without awaiting. The cubit stops
  /// mirroring the session at once, too.
  @override
  Future<void> close() async {
    // Before the first await: a BlocProvider calls close() without awaiting
    // it and may close the host next, so an agent event that arrives later
    // must find the session disposed already.
    final disposal = session.dispose();
    await _views.cancel();
    await disposal;
    await super.close();
  }
}
