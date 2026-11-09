import 'package:uuid/uuid.dart';

/// The id of an AG-UI thread, which every run sends.
sealed class ThreadId {
  /// An id the app supplies, such as the backend's own id of the
  /// conversation.
  ///
  /// Throws an [ArgumentError] when [id] is empty.
  factory(String id) = AppThreadId;

  String get value;
}

/// An id the app supplied. A reset keeps it, and the backend may still hold
/// the conversation.
final class AppThreadId(String id) implements ThreadId {
  @override
  final String value = id.isEmpty
      ? throw ArgumentError.value(id, 'id', 'A thread id is not empty.')
      : id;

  @override
  bool operator ==(Object other) =>
      other is AppThreadId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// An id Tandem picked. A reset replaces it, so the backend starts a new
/// conversation.
final class GeneratedThreadId() implements ThreadId {
  @override
  final String value = const Uuid().v4();
}
