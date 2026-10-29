import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/genui/agent_catalog.dart';

/// The types that a catalog and a screen, built apart, both describe.
abstract final class ViewTypes._() {
  /// Why [catalog] and [listing] do not fit, or null when they do: a type
  /// that both describe, read or written differently, such as `Color` with
  /// two converters. Two descriptions with one id and one fingerprint read
  /// and write the same JSON; the fingerprint does not prove that two
  /// converters of one class and configuration behave the same.
  static String? conflict({
    required AgentCatalog catalog,
    required AgentListing listing,
  }) {
    final inCatalog = <String, AgentType<Object?>>{};
    for (final component in catalog.components) {
      for (final property in component.properties) {
        switch (property) {
          case ValueProperty(:final type) || FieldProperty(:final type):
            _collect(type, inCatalog);
          default:
        }
      }
    }
    final onScreen = <String, AgentType<Object?>>{};
    for (final MapEntry(:value) in listing.roots.entries) {
      _collect(value.type, onScreen);
    }
    for (final name in listing.toolNames) {
      for (final parameter
          in listing.toolNamed(name)?.parameters ??
              const <AgentParameter<Object?>>[]) {
        _collect(parameter.type, onScreen);
      }
    }
    for (final MapEntry(key: id, value: type) in onScreen.entries) {
      final other = inCatalog[id]?.fingerprint;
      if (other != null && other != type.fingerprint) {
        return '${catalog.runtimeType} and the screen describe '
            '${type.name} differently: $other in the catalog, '
            '${type.fingerprint} on the screen. Give both the same converters.';
      }
    }
    return null;
  }

  static void _collect(
    AgentType<Object?> type,
    Map<String, AgentType<Object?>> into,
  ) {
    if (into.containsKey(type.id)) return;
    into[type.id] = type;
    for (final part in type.parts) {
      _collect(part, into);
    }
  }
}
