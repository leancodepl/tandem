// Internal: not exported. The session uses it for per-leaf merges of agent
// writes, for agent marks and for the user edits it reports.

import 'dart:math';

import 'package:tandem/src/protocol/json_patch/json_value.dart';

/// One change between two versions of a JSON document: [path] got [value],
/// or was removed.
final class JsonChange {
  /// A change that sets [path] to [value].
  const JsonChange.set(this.path, this.value) : isRemoval = false;

  /// A change that removes [path].
  const JsonChange.remove(this.path) : isRemoval = true, value = null;

  /// The reference tokens of the changed place, such as
  /// `['order', 'lines', '1', 'quantity']`.
  final List<String> path;

  /// Whether the place no longer exists.
  final bool isRemoval;

  /// The new value, unless [isRemoval].
  final Object? value;

  @override
  String toString() =>
      isRemoval ? 'remove /${path.join('/')}' : 'set /${path.join('/')}';
}

/// How [diffJson] treats a list whose length changed.
enum ListDiff {
  /// The list changed as a whole: one change of the list itself. This is how
  /// agent writes are merged, because list items are addressed by index.
  whole,

  /// Item by item: changes of the common items, then one change per added
  /// or removed item at the end. This is what agent marks and user edits
  /// name.
  items,
}

/// The changes from [before] to [after] in the top-level [keys].
///
/// Equal values (in the sense of [jsonEquals]) are no change, so restating a
/// value is never a change. Objects are compared key by key, lists of the
/// same length item by item; anything else that differs is one change of
/// the whole value.
List<JsonChange> diffJson(
  Map<String, Object?> before,
  Map<String, Object?> after,
  Iterable<String> keys, {
  required ListDiff lists,
}) {
  final changes = <JsonChange>[];
  for (final key in keys) {
    final had = before.containsKey(key);
    final has = after.containsKey(key);
    if (had && !has) {
      changes.add(JsonChange.remove([key]));
    } else if (!had && has) {
      changes.add(JsonChange.set([key], after[key]));
    } else if (had && has) {
      _diff(before[key], after[key], [key], changes, lists);
    }
  }
  return changes;
}

void _diff(
  Object? before,
  Object? after,
  List<String> path,
  List<JsonChange> changes,
  ListDiff lists,
) {
  switch ((before, after)) {
    case (final Map<String, Object?> before, final Map<String, Object?> after):
      for (final key in before.keys) {
        if (!after.containsKey(key)) {
          changes.add(JsonChange.remove([...path, key]));
        }
      }
      for (final MapEntry(:key, :value) in after.entries) {
        if (before.containsKey(key)) {
          _diff(before[key], value, [...path, key], changes, lists);
        } else {
          changes.add(JsonChange.set([...path, key], value));
        }
      }
    case (final List<Object?> before, final List<Object?> after)
        when before.length == after.length || lists == ListDiff.items:
      final common = min(before.length, after.length);
      for (var index = 0; index < common; index++) {
        _diff(before[index], after[index], [...path, '$index'], changes, lists);
      }
      for (var index = common; index < after.length; index++) {
        changes.add(JsonChange.set([...path, '$index'], after[index]));
      }
      for (var index = before.length - 1; index >= common; index--) {
        changes.add(JsonChange.remove([...path, '$index']));
      }
    case _ when !jsonEquals(before, after):
      changes.add(JsonChange.set(path, after));
    case _:
      break;
  }
}

/// The paths of the leaves of [value] at [path]: values that are neither a
/// non-empty object nor a non-empty list.
Iterable<List<String>> leavesOf(Object? value, List<String> path) sync* {
  switch (value) {
    case final Map<String, Object?> object when object.isNotEmpty:
      for (final MapEntry(:key, value: child) in object.entries) {
        yield* leavesOf(child, [...path, key]);
      }
    case final List<Object?> list when list.isNotEmpty:
      for (final (index, child) in list.indexed) {
        yield* leavesOf(child, [...path, '$index']);
      }
    default:
      yield path;
  }
}

/// The value at [path] in [document], and whether it exists.
({bool exists, Object? value}) jsonAt(
  Map<String, Object?> document,
  List<String> path,
) {
  Object? current = document;
  for (final token in path) {
    switch (current) {
      case final Map<String, Object?> object when object.containsKey(token):
        current = object[token];
      case final List<Object?> list:
        final index = _index(token, list.length);
        if (index == null) {
          return (exists: false, value: null);
        }
        current = list[index];
      default:
        return (exists: false, value: null);
    }
  }
  return (exists: true, value: current);
}

/// [changes] applied to a copy of [document], and the changes that did not
/// fit because their place no longer exists in [document].
///
/// A change of a top-level key always fits. Any other change needs its
/// parent: an object, or a list that still has the item.
({Map<String, Object?> document, List<JsonChange> dropped}) applyJsonChanges(
  Map<String, Object?> document,
  List<JsonChange> changes,
) {
  final result = copyJsonObject(document);
  final dropped = <JsonChange>[];
  for (final change in changes) {
    final parent = jsonAt(
      result,
      change.path.sublist(0, change.path.length - 1),
    );
    final last = change.path.last;
    switch (parent.value) {
      case final Map<String, Object?> object when parent.exists:
        if (change.isRemoval) {
          object.remove(last);
        } else {
          object[last] = copyJson(change.value);
        }
      case final List<Object?> list when parent.exists:
        final index = _index(last, list.length);
        if (index == null) {
          dropped.add(change);
        } else if (change.isRemoval) {
          list.removeAt(index);
        } else {
          list[index] = copyJson(change.value);
        }
      default:
        dropped.add(change);
    }
  }
  return (document: result, dropped: dropped);
}

/// Whether one of [a] and [b] is the other or lies below it.
bool overlaps(List<String> a, List<String> b) {
  final common = min(a.length, b.length);
  for (var i = 0; i < common; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// [token] as an index of a list of [length] items, or `null`.
int? _index(String token, int length) {
  final index = int.tryParse(token);
  if (index == null || index < 0 || index >= length || '$index' != token) {
    return null;
  }
  return index;
}
