/// A call of a listed method that returned.
final class const AgentCall({
  /// The method's name in snake_case.
  required final String tool,
  required final Map<String, Object?> arguments,

  /// What the method returned, as JSON.
  required final Object? result,
});

/// Not called for a call that was refused or threw, nor once the session is
/// disposed.
typedef AgentCallListener = void Function(AgentCall call);
