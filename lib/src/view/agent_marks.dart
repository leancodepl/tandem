import 'package:meta/meta.dart';

/// Which leaves of the shared state the agent wrote last, so the screen can
/// highlight what the agent filled in.
///
/// Paths use `/` between keys and list indexes, without a leading `/`. For
/// `StateCodec.json` and `StateCodec.lens` they are relative to the codec's
/// key (`'customer'`, `'lines/1/quantity'`); for `StateCodec.custom` they
/// start with the top-level key.
@immutable
final class AgentMarks {
  /// Creates marks. The session creates them; public for widget tests.
  const AgentMarks({this.paths = const {}, Set<String> latest = const {}})
    : _latest = latest;

  /// No leaf is marked.
  static const none = AgentMarks();

  /// The marked leaf paths.
  final Set<String> paths;

  /// The leaf paths changed in the agent's most recent update.
  final Set<String> _latest;

  /// Whether the agent is the last writer of the leaf at [path] or of a leaf
  /// below it. A user edit of a leaf clears its mark.
  ///
  /// `has('lines/1')` is `true` when `'lines/1/quantity'` is marked; `has('')`
  /// is `true` when anything is marked.
  bool has(String path) => _covers(paths, path);

  /// Whether [path], or a leaf below it, changed in the agent's most recent
  /// update. Useful for a short "just changed" animation.
  bool isLatest(String path) => _covers(_latest, path);

  static bool _covers(Set<String> leaves, String path) {
    if (path.isEmpty) {
      return leaves.isNotEmpty;
    }
    if (leaves.contains(path)) {
      return true;
    }
    final prefix = '$path/';
    return leaves.any((leaf) => leaf.startsWith(prefix));
  }
}
