import 'dart:async';
import 'dart:collection';

/// Where the shared state lives in the app.
///
/// Tandem never owns the shared state. The screen keeps its own state holder
/// (usually its cubit), so its form, computed totals and validation keep
/// working unchanged. Tandem reads the state from the host, listens to it,
/// and writes the agent's changes into it.
///
/// The member names match bloc's `StateStreamable`, so a `Cubit` or `Bloc`
/// already has [state] and [stream]; the `AgentEditable` mixin from
/// `package:tandem_bloc` adds [writeFromAgent]. For plain Dart and tests,
/// use [StateHost.memory].
abstract interface class StateHost<S> {
  /// A host that keeps the value in memory; see [MemoryStateHost].
  factory StateHost.memory(S initial) = MemoryStateHost<S>;

  /// The current value. Tandem reads it whenever it needs it: to build a
  /// run, to check an approval, to run a tool.
  S get state;

  /// Every new value from any writer, including the values Tandem wrote with
  /// [writeFromAgent]. It may deliver asynchronously, as bloc does.
  ///
  /// Tandem tells the user's edits from its own writes by content, so the
  /// host does not need to say who changed the value.
  Stream<S> get stream;

  /// Writes a value built from the agent's state. Called by Tandem only.
  ///
  /// Afterwards [state] is [value], and [value] is emitted on [stream] unless
  /// it equals the previous value. Tandem never calls it after its session
  /// is disposed.
  void writeFromAgent(S value);
}

/// A [StateHost] that keeps the value in memory, for plain Dart callers and
/// tests.
///
/// Unlike bloc, it delivers every new value on [stream] synchronously,
/// during [update] or [writeFromAgent]. A value written by a listener while
/// another value is being delivered is delivered right after it, so
/// listeners always see the values in order. Like bloc, it emits nothing
/// when the new value `==` the current one.
final class MemoryStateHost<S> implements StateHost<S> {
  /// Creates a host holding [initial].
  MemoryStateHost(S initial) : _state = initial;

  S _state;

  final _controller = StreamController<S>.broadcast(sync: true);
  final _undelivered = Queue<S>();
  var _isDelivering = false;

  /// Applies a user edit, as a form would: [edit] gets the current value and
  /// returns the new one.
  void update(S Function(S current) edit) => _set(edit(_state));

  @override
  S get state => _state;

  @override
  Stream<S> get stream => _controller.stream;

  @override
  void writeFromAgent(S value) => _set(value);

  void _set(S value) {
    if (value == _state) {
      return;
    }
    _state = value;
    _undelivered.add(value);
    if (_isDelivering) {
      return;
    }
    _isDelivering = true;
    try {
      while (_undelivered.isNotEmpty) {
        _controller.add(_undelivered.removeFirst());
      }
    } finally {
      _isDelivering = false;
    }
  }
}
