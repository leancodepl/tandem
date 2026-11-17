import 'dart:convert';

import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';

/// What the agent sees: the `.sees` of an agent list, as AG-UI `context`.
/// Two snapshots are equal when the agent sees the same in both.
final class SeesSnapshot._(final Object _key) {
  /// What [listing] gave the agent.
  factory of(AgentListing listing) => ._(jsonEncode(listing.context));

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
      // A failed read must differ from every other snapshot.
      return ._(Object());
    }
  }

  @override
  bool operator ==(Object other) => other is SeesSnapshot && _key == other._key;

  @override
  int get hashCode => _key.hashCode;
}
