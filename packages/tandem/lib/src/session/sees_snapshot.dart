import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';

/// What the agent sees: the `.sees` of an agent list, as AG-UI `context`.
/// Two snapshots are equal when the agent sees the same in both.
sealed class SeesSnapshot {
  /// What [listing] gave the agent.
  factory of(AgentListing listing) => _Read(jsonEncode(listing.context));

  /// What the agent sees on [surface] now. Never throws: when the agent list
  /// throws, [report] gets the error and the snapshot equals no other.
  factory read(
    AgentSurface surface, {
    required void Function(Object error, StackTrace stack) report,
  }) {
    try {
      return .of(AgentListing.of(surface));
    } catch (err, st) {
      report(err, st);
      return _Unreadable();
    }
  }
}

/// The `.sees` an agent list gave, as JSON.
final class _Read(final String _json) implements SeesSnapshot {
  @override
  bool operator ==(Object other) => other is _Read && other._json == _json;

  @override
  int get hashCode => _json.hashCode;
}

/// A `.sees` that could not be read. What the agent sees is unknown, so it
/// equals only itself and every comparison counts as a change.
final class _Unreadable() implements SeesSnapshot;
