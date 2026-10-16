// Internal: not exported. The session (STATE_DELTA) and the scripted agent
// (AgentStep.patchState) use it.

import 'dart:convert';

import 'package:tandem/src/protocol/json_patch/json_pointer.dart';
import 'package:tandem/src/protocol/json_patch/json_value.dart';

/// Applies the RFC 6902 [operations] to [document] and returns the result.
///
/// Supports `add`, `remove`, `replace`, `move`, `copy` and `test`, with RFC
/// 6901 paths (`~0`, `~1`, `-` for the end of a list). All or nothing: when
/// one operation fails, nothing is applied and a [JsonPatchException] is
/// thrown. [document] is never modified; the result shares no mutable
/// structure with it.
///
/// Members of an operation other than `op`, `path`, `from` and `value` are
/// ignored, as RFC 6902 requires. The result must be a JSON object, so an
/// operation that turns the whole document into something else fails.
Map<String, Object?> applyJsonPatch(
  Map<String, Object?> document,
  List<Map<String, Object?>> operations,
) {
  final patch = _Patch(copyJsonObject(document));
  operations.forEach(patch.apply);
  return switch (patch.root) {
    final Map<String, Object?> result => result,
    final other => throw JsonPatchException(
      'the result is ${_describe(other)}, not a JSON object',
    ),
  };
}

/// A JSON Patch that could not be applied.
final class JsonPatchException implements Exception {
  /// Creates the exception.
  const JsonPatchException(this.message, {this.operation});

  /// What failed, such as `path "/order/lines/7" does not exist`.
  final String message;

  /// The operation that failed, when one did.
  final Map<String, Object?>? operation;

  @override
  String toString() => operation == null
      ? 'JsonPatchException: $message'
      : 'JsonPatchException: $message in $operation';
}

/// Applies operations one by one to a private copy of the document.
///
/// Every value that goes into [root] is a fresh copy, so [root] can be
/// changed in place and no caller ever sees a half-applied patch.
final class _Patch {
  _Patch(this.root);

  /// The document so far; any JSON value while the patch runs.
  Object? root;

  void apply(Map<String, Object?> operation) {
    final op = _Operation(operation);
    switch (op.string('op')) {
      case 'add':
        _add(op, op.path('path'), copyJson(op.value()));
      case 'remove':
        _remove(op, op.path('path'));
      case 'replace':
        _replace(op, op.path('path'), copyJson(op.value()));
      case 'move':
        _move(op, from: op.path('from'), to: op.path('path'));
      case 'copy':
        final value = copyJson(_get(op, op.path('from')));
        _add(op, op.path('path'), value);
      case 'test':
        _test(op, op.path('path'), op.value());
      case final name:
        throw op.fail('unknown op "$name"');
    }
  }

  void _add(_Operation op, _Path path, Object? value) {
    if (path.isRoot) {
      root = value;
      return;
    }
    switch (_get(op, path.parent)) {
      case final Map<String, Object?> object:
        object[path.last] = value;
      case final List<Object?> list:
        final index = path.last == '-'
            ? list.length
            : _index(op, path, list, allowEnd: true);
        list.insert(index, value);
      case final other:
        throw op.fail(
          'cannot add "${path.pointer}": the parent is ${_describe(other)}',
        );
    }
  }

  Object? _remove(_Operation op, _Path path) {
    if (path.isRoot) {
      throw op.fail('cannot remove the whole document');
    }
    switch (_get(op, path.parent)) {
      case final Map<String, Object?> object:
        if (!object.containsKey(path.last)) {
          throw op.fail('path "${path.pointer}" does not exist');
        }
        return object.remove(path.last);
      case final List<Object?> list:
        return list.removeAt(_index(op, path, list, allowEnd: false));
      case _:
        throw op.fail('path "${path.pointer}" does not exist');
    }
  }

  void _replace(_Operation op, _Path path, Object? value) {
    if (path.isRoot) {
      root = value;
      return;
    }
    switch (_get(op, path.parent)) {
      case final Map<String, Object?> object:
        if (!object.containsKey(path.last)) {
          throw op.fail('path "${path.pointer}" does not exist');
        }
        object[path.last] = value;
      case final List<Object?> list:
        list[_index(op, path, list, allowEnd: false)] = value;
      case _:
        throw op.fail('path "${path.pointer}" does not exist');
    }
  }

  void _move(_Operation op, {required _Path from, required _Path to}) {
    if (to.isInside(from)) {
      throw op.fail(
        'cannot move "${from.pointer}" into its own child "${to.pointer}"',
      );
    }
    // The value is already a private copy, so it can move as it is.
    _add(op, to, _remove(op, from));
  }

  void _test(_Operation op, _Path path, Object? expected) {
    final actual = _get(op, path);
    if (!jsonEquals(actual, expected)) {
      throw op.fail(
        'test failed: "${path.pointer}" is ${_describe(actual)}, '
        'expected ${_describe(expected)}',
      );
    }
  }

  /// The value at [path], which must exist.
  Object? _get(_Operation op, _Path path) {
    var current = root;
    for (var depth = 0; depth < path.tokens.length; depth++) {
      final token = path.tokens[depth];
      switch (current) {
        case final Map<String, Object?> object when object.containsKey(token):
          current = object[token];
        case final List<Object?> list:
          current = list[_index(op, path, list, allowEnd: false, at: depth)];
        case _:
          throw op.fail('path "${path.pointer}" does not exist');
      }
    }
    return current;
  }

  /// The list index at token [at] of [path] (default: the last token).
  ///
  /// [allowEnd] accepts `list.length`, where `add` inserts at the end.
  int _index(
    _Operation op,
    _Path path,
    List<Object?> list, {
    required bool allowEnd,
    int? at,
  }) {
    final token = path.tokens[at ?? path.tokens.length - 1];
    if (!_arrayIndex.hasMatch(token)) {
      throw op.fail(
        token == '-'
            ? '"-" in "${path.pointer}" has no element to '
                  '${op.string('op')}'
            : '"$token" in "${path.pointer}" is not a list index',
      );
    }
    final index = int.tryParse(token);
    final end = allowEnd ? list.length : list.length - 1;
    if (index == null || index > end) {
      throw op.fail(
        'index $token in "${path.pointer}" is out of range '
        '(the list has ${list.length} items)',
      );
    }
    return index;
  }

  /// An RFC 6901 array index: `0`, or digits without a leading zero.
  static final _arrayIndex = RegExp(r'^(0|[1-9][0-9]*)$');
}

/// One operation of a patch, with checked reads of its members.
final class _Operation {
  const _Operation(this.json);

  final Map<String, Object?> json;

  String string(String member) => switch (json[member]) {
    final String value => value,
    _ => throw fail('"$member" is missing or not a string'),
  };

  _Path path(String member) {
    final pointer = string(member);
    try {
      return _Path(pointer, parseJsonPointer(pointer));
    } on FormatException catch (err) {
      throw fail('"$member" is not a JSON Pointer: ${err.message}');
    }
  }

  Object? value() {
    if (!json.containsKey('value')) {
      throw fail('"value" is missing');
    }
    return json['value'];
  }

  JsonPatchException fail(String message) =>
      JsonPatchException(message, operation: json);
}

/// A parsed JSON Pointer that remembers how it was written.
final class _Path {
  const _Path(this.pointer, this.tokens);

  final String pointer;
  final List<String> tokens;

  bool get isRoot => tokens.isEmpty;

  String get last => tokens.last;

  _Path get parent {
    final parentTokens = tokens.sublist(0, tokens.length - 1);
    return _Path(formatJsonPointer(parentTokens), parentTokens);
  }

  /// Whether this path is strictly below [other].
  bool isInside(_Path other) {
    if (tokens.length <= other.tokens.length) {
      return false;
    }
    for (var i = 0; i < other.tokens.length; i++) {
      if (tokens[i] != other.tokens[i]) {
        return false;
      }
    }
    return true;
  }
}

/// A JSON value as compact JSON for error messages, cut after 100
/// characters.
String _describe(Object? value) {
  final json = jsonEncode(value, toEncodable: (object) => '$object');
  return json.length <= 100 ? json : '${json.substring(0, 100)}…';
}
