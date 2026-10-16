// Internal: not exported.

import 'dart:async';
import 'dart:convert';

import 'package:tandem/src/protocol/json_patch/json_patch.dart';
import 'package:tandem/src/protocol/json_patch/json_pointer.dart';
import 'package:tandem/src/protocol/json_patch/json_value.dart';
import 'package:tandem/src/protocol/wire/wire_conventions.dart';
import 'package:tandem/src/state/json_diff.dart';
import 'package:tandem/src/state/state_codec.dart';
import 'package:tandem/src/state/state_host.dart';
import 'package:tandem/src/view/agent_marks.dart';

/// The session's side of the shared state: the agent's document, the merge
/// of agent writes into the host, the detection of the user's edits, and the
/// agent marks.
///
/// - The agent's whole document is kept, server keys included, so JSON
///   Patch paths stay valid. At the start of a run the app's state is merged
///   into it per top-level key, as ag-ui-adk does.
/// - An agent write is the set of owned leaves in which a new document
///   differs from the previous one; restating a value is not a write. The
///   write is merged into the host's current value leaf by leaf (last write
///   wins), so a value the user typed during the run survives the run's
///   final snapshot.
/// - Every value written into the host is kept until the host echoes it. A
///   host value that matches none of them and differs from the last known
///   value is a user edit.
/// - [sync] takes in a host value the host's stream has not delivered yet,
///   so an edit made in the same synchronous block as a run start counts
///   for that run.
final class SharedState<S> {
  /// Starts listening to [host].
  ///
  /// [onChange] is called after every host value and every agent write;
  /// [diagnose] receives what was ignored.
  SharedState({
    required StateHost<S> host,
    required StateCodec<S> codec,
    required void Function(String message, Object? detail) diagnose,
    required void Function() onChange,
  }) : _host = host,
       _codec = codec,
       _diagnose = diagnose,
       _onChange = onChange,
       _keys = {
         ...codec.keys.where((key) => !WireConventions.isServerKey(key)),
       },
       _marksKey = marksKeyOf(codec) {
    final serverKeys = codec.keys.where(WireConventions.isServerKey).toList();
    if (serverKeys.isNotEmpty) {
      diagnose(
        'The codec claims keys of the agent backend, which are never sent: '
        '${serverKeys.join(', ')}.',
        codec,
      );
    }
    _lastKnown = encode();
    _subscription = host.stream.listen(_onHostValue);
  }

  final StateHost<S> _host;
  final StateCodec<S> _codec;
  final void Function(String message, Object? detail) _diagnose;
  final void Function() _onChange;
  final Set<String> _keys;
  final String? _marksKey;
  late final StreamSubscription<S> _subscription;

  /// The agent's whole document, server keys included.
  var _document = <String, Object?>{};

  /// The encoded host value Tandem knows, as of the last host value seen.
  late Map<String, Object?> _lastKnown;

  /// The encoded host values Tandem has taken in and the host's stream has
  /// not delivered yet, oldest first: values it wrote, and values [sync]
  /// read (`isSynced`).
  final _echoes = <({Map<String, Object?> value, bool isSynced})>[];

  /// The agent marks: leaf pointers to their reference tokens.
  final _marks = <String, List<String>>{};

  /// The pointers of [_marks] that the agent's latest write changed.
  var _latest = <String>{};

  AgentMarks? _marksView;

  /// The leaves the user changed since they were last taken: JSON Pointers
  /// to their reference tokens, oldest first.
  final _userEdits = <String, List<String>>{};

  var _isClosed = false;

  /// The agent marks, for the view.
  AgentMarks get marks => _marksView ??= AgentMarks(
    paths: Set.unmodifiable(_marks.values.map(_markPath).nonNulls),
    latest: Set.unmodifiable(
      _latest
          .map((pointer) => _marks[pointer])
          .nonNulls
          .map(_markPath)
          .nonNulls,
    ),
  );

  /// The owned part of the host's current value, as plain JSON.
  Map<String, Object?> encode() => _encode(_host.state);

  /// Whether the user changed the shared state since the edits were last
  /// taken, in a way the agent has not overwritten since.
  bool get hasUserEdits => _userEdits.isNotEmpty;

  /// Takes in the host's current value now, before its stream delivers it.
  ///
  /// An asynchronous host (bloc) delivers an edit in a later microtask, so
  /// an edit made in the same synchronous block as a run start would count
  /// one run late. A difference from the value Tandem knows is a user edit
  /// now; the deliveries up to that value are then not counted again.
  void sync() {
    if (_isClosed) {
      return;
    }
    final current = encode();
    final known = _echoes.isEmpty ? _lastKnown : _echoes.last.value;
    if (jsonEquals(current, known)) {
      return;
    }
    _recordUserEdit(known, current);
    _echoes.add((value: current, isSynced: true));
  }

  /// Starts a run: returns the state to send, which is merged into the
  /// agent's document per top-level key.
  Map<String, Object?> startRun() {
    final state = encode();
    _document = {..._document, ...copyJsonObject(state)};
    return state;
  }

  /// A `STATE_SNAPSHOT`: [snapshot] replaces the agent's document.
  void applySnapshot(Map<String, Object?> snapshot) =>
      _applyDocument(copyJsonObject(snapshot));

  /// A `STATE_DELTA`: [operations] change the agent's document. A patch that
  /// does not apply is ignored and reported.
  void applyDelta(List<Map<String, Object?>> operations) {
    final Map<String, Object?> document;
    try {
      document = applyJsonPatch(_document, operations);
    } on JsonPatchException catch (error) {
      _diagnose(
        'Ignored a STATE_DELTA that does not apply to the agent state: '
        '${error.message}.',
        error,
      );
      return;
    }
    _applyDocument(document);
  }

  /// The user's edits since the last call, as JSON Pointers into the state,
  /// oldest first.
  List<String> takeUserEdits() {
    final edits = _userEdits.keys.toList();
    _userEdits.clear();
    return edits;
  }

  /// Puts [edits] taken for a run that never started back, before the edits
  /// made since.
  void restoreUserEdits(List<String> edits) {
    final since = Map.of(_userEdits);
    _userEdits
      ..clear()
      ..addAll({for (final edit in edits) edit: parseJsonPointer(edit)})
      ..addAll(since);
  }

  /// Stops listening to the host and writing into it, synchronously.
  Future<void> close() {
    _isClosed = true;
    return _subscription.cancel();
  }

  void _applyDocument(Map<String, Object?> document) {
    final before = _document;
    _document = document;
    if (_isClosed) {
      return;
    }
    final writes = diffJson(before, document, _keys, lists: ListDiff.whole);
    if (writes.isEmpty) {
      return;
    }
    final current = _host.state;
    final encoded = _encode(current);
    final merged = applyJsonChanges(encoded, writes);
    for (final change in merged.dropped) {
      _diagnose(
        'Dropped the agent change of ${formatJsonPointer(change.path)}: the '
        'user removed the place it belongs to.',
        change,
      );
    }
    if (!jsonEquals(merged.document, encoded)) {
      final S value;
      final Map<String, Object?> landed;
      try {
        value = _codec.decode(current, {...document, ...merged.document});
        landed = _encode(value);
      } on Object catch (error) {
        _diagnose(
          'The codec could not decode the agent state; the current value '
          'was kept.',
          error,
        );
        return;
      }
      if (!jsonEquals(landed, encoded)) {
        _echoes.add((value: landed, isSynced: false));
        _host.writeFromAgent(value);
      }
    }
    // Read again: a synchronous host's listeners may have changed the value
    // while it was delivered.
    _markWrite(before, document, encoded, encode());
    _onChange();
  }

  /// Marks the leaves the agent is now the last writer of: the leaves it
  /// changed from [before] to [after], and the leaves its write changed in
  /// the host from [hostBefore] to [hostAfter] (such as a user edit that a
  /// list taken whole reverted), where the host holds the agent's value.
  ///
  /// A user edit the write overwrote with the agent's value is no longer
  /// reported.
  void _markWrite(
    Map<String, Object?> before,
    Map<String, Object?> after,
    Map<String, Object?> hostBefore,
    Map<String, Object?> hostAfter,
  ) {
    final latest = <String>{};
    final changes = [
      ...diffJson(before, after, _keys, lists: ListDiff.items),
      ...diffJson(hostBefore, hostAfter, _keys, lists: ListDiff.items),
    ];
    for (final change in changes) {
      _unmark(change.path);
      if (change.isRemoval) {
        continue;
      }
      for (final leaf in leavesOf(change.value, change.path)) {
        if (_isSame(jsonAt(hostAfter, leaf), jsonAt(after, leaf))) {
          final pointer = formatJsonPointer(leaf);
          _marks[pointer] = leaf;
          latest.add(pointer);
        }
      }
    }
    _userEdits.removeWhere((pointer, path) {
      final had = jsonAt(hostBefore, path);
      final has = jsonAt(hostAfter, path);
      return !_isSame(had, has) && _isSame(has, jsonAt(after, path));
    });
    _latest = latest;
    _marksView = null;
  }

  void _onHostValue(S value) {
    if (_isClosed) {
      return;
    }
    final encoded = _encode(value);
    final echo = _echoes.indexWhere(
      (taken) => jsonEquals(taken.value, encoded),
    );
    if (echo != -1) {
      _echoes.removeRange(0, echo + 1);
      _lastKnown = encoded;
    } else if (_echoes.any((taken) => taken.isSynced)) {
      // A value before one that [sync] took in; its changes are counted.
    } else if (!jsonEquals(encoded, _lastKnown)) {
      _recordUserEdit(_lastKnown, encoded);
      _lastKnown = encoded;
    }
    _onChange();
  }

  /// The user changed the host's value from [before] to [after].
  void _recordUserEdit(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) {
    for (final edit in diffJson(before, after, _keys, lists: ListDiff.items)) {
      _unmark(edit.path);
      _userEdits.putIfAbsent(formatJsonPointer(edit.path), () => edit.path);
    }
    _marksView = null;
  }

  /// Whether [a] and [b] are the same place: both missing, or both there
  /// with equal values.
  static bool _isSame(
    ({bool exists, Object? value}) a,
    ({bool exists, Object? value}) b,
  ) => a.exists == b.exists && (!a.exists || jsonEquals(a.value, b.value));

  /// Removes the marks at, below and above [path].
  void _unmark(List<String> path) {
    _marks.removeWhere((pointer, leaf) => overlaps(leaf, path));
    _latest.removeWhere((pointer) => !_marks.containsKey(pointer));
  }

  /// [leaf] as an [AgentMarks] path, or `null` when it has none.
  String? _markPath(List<String> leaf) {
    final key = _marksKey;
    final tokens = key == null ? leaf : leaf.skip(1);
    if (key != null && (leaf.isEmpty || leaf.first != key)) {
      return null;
    }
    final path = tokens.join('/');
    return path.isEmpty ? null : path;
  }

  /// The owned keys of [value]'s encoding, as plain JSON.
  Map<String, Object?> _encode(S value) {
    final encoded = _codec.encode(value);
    final json = jsonDecode(jsonEncode(encoded)) as Map<String, Object?>;
    return {
      for (final key in _keys)
        if (json.containsKey(key)) key: json[key],
    };
  }
}
