/// The id of an AG-UI thread, which every run sends.
final class ThreadId(String id) {
  /// An id the app supplies, such as the backend's own id of the
  /// conversation.
  ///
  /// Throws an [ArgumentError] when [id] is empty.
  this;

  final String value = id.isEmpty
      ? throw ArgumentError.value(id, 'id', 'A thread id is not empty.')
      : id;

  @override
  bool operator ==(Object other) => other is ThreadId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
