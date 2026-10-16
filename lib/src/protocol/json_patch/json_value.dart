// Internal: not exported. Shared by JSON Patch, the session (echo detection,
// per-leaf merges) and the scripted agent.

/// Whether [a] and [b] are the same JSON value.
///
/// Objects are equal when they have the same keys with equal values, in any
/// order; lists when they have equal items in the same order. Numbers compare
/// by value, so `40` equals `40.0`.
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  switch ((a, b)) {
    case (final Map<String, Object?> a, final Map<String, Object?> b):
      if (a.length != b.length) {
        return false;
      }
      for (final MapEntry(:key, :value) in a.entries) {
        if (!b.containsKey(key) || !jsonEquals(value, b[key])) {
          return false;
        }
      }
      return true;
    case (final List<Object?> a, final List<Object?> b):
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (!jsonEquals(a[i], b[i])) {
          return false;
        }
      }
      return true;
    case (Map<Object?, Object?>() || List<Object?>(), _):
    case (_, Map<Object?, Object?>() || List<Object?>()):
      return false;
    default:
      return a == b;
  }
}

/// A deep copy of the JSON [value] whose objects and lists are new, growable
/// and modifiable (`Map<String, Object?>` and `List<Object?>`).
Object? copyJson(Object? value) => switch (value) {
  final Map<String, Object?> object => <String, Object?>{
    for (final MapEntry(:key, :value) in object.entries) key: copyJson(value),
  },
  final List<Object?> list => <Object?>[
    for (final item in list) copyJson(item),
  ],
  _ => value,
};

/// A deep copy of the JSON object [document]; see [copyJson].
Map<String, Object?> copyJsonObject(Map<String, Object?> document) =>
    copyJson(document)! as Map<String, Object?>;
