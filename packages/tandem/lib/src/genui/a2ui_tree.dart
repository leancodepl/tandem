import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The components of every `updateComponents` of [messages], by id.
Map<String, JsonObject> componentsOf(List<Object?> messages) => {
  for (final message in messages)
    for (final component in componentsIn(message))
      if (component[A2uiFields.id] case final String id) id: component,
};

/// The components of [message], when it is an `updateComponents`.
Iterable<JsonObject> componentsIn(Object? message) => switch (message) {
  {
    A2uiFields.updateComponents: {
      A2uiFields.components: final List<Object?> components,
    },
  } =>
    components.whereType<JsonObject>(),
  _ => const [],
};

/// The list path that each component of a list template, and everything
/// below it, reads its relative paths from, by component id.
Map<String, String> templateBases(Map<String, JsonObject> components) {
  final bases = <String, String>{};
  void mark(String id, String base) {
    if (bases.containsKey(id)) {
      return;
    }
    bases[id] = base;
    for (final child in _childIds(components[id])) {
      mark(child, base);
    }
  }

  for (final component in components.values) {
    if (component[A2uiFields.children] case {
      A2uiFields.componentId: final String id,
      A2uiFields.path: final String path,
    }) {
      mark(id, path);
    }
  }
  return bases;
}

/// Every data path [json] binds: a `{"path": ...}`, the list of a template
/// and each `${...}` of a `formatString`.
Iterable<String> pathsOf(Object? json) => switch (json) {
  {A2uiFields.path: final String path} when json.length == 1 => [path],
  {A2uiFields.componentId: _, A2uiFields.path: final String path} => [path],
  {
    A2uiFields.call: _,
    A2uiFields.args: {A2uiFields.value: final String text},
  } =>
    _interpolation.allMatches(text).map((match) => match[1] ?? ''),
  Map<Object?, Object?>() => json.values.expand(pathsOf),
  List<Object?>() => json.expand(pathsOf),
  _ => const [],
};

/// The names of the functions [json] calls.
Iterable<String> functionsOf(Object? json) => switch (json) {
  {A2uiFields.call: final String name} => [name],
  Map<Object?, Object?>() => json.values.expand(functionsOf),
  List<Object?>() => json.expand(functionsOf),
  _ => const [],
};

/// The `event` of every action in [json].
Iterable<JsonObject> eventsOf(Object? json) => switch (json) {
  {A2uiFields.event: final JsonObject event} => [event],
  Map<Object?, Object?>() => json.values.expand(eventsOf),
  List<Object?>() => json.expand(eventsOf),
  _ => const [],
};

/// Whether an action in [json] runs a function on the device.
bool hasFunctionCall(Object? json) => switch (json) {
  Map<Object?, Object?>() when json.containsKey(A2uiFields.functionCall) =>
    true,
  Map<Object?, Object?>() => json.values.any(hasFunctionCall),
  List<Object?>() => json.any(hasFunctionCall),
  _ => false,
};

/// Why [path] finds nothing in [data], or null when it finds a value or
/// cannot tell, as in an empty list. A relative path reads from the first
/// item of the list at [base], and `.` is that item.
String? whyUnresolved(
  String path, {
  required String? base,
  required Map<String, Object?> data,
}) {
  final segments = _segments(path, base);
  if (segments == null) {
    return 'relative path $path outside a list template.';
  }
  Object? value = data;
  for (final segment in segments) {
    switch (value) {
      case final Map<Object?, Object?> map when map.containsKey(segment):
        value = map[segment];
      case final List<Object?> list when list.isEmpty:
        return null;
      case final List<Object?> list:
        final index = int.tryParse(segment);
        if (index == null || index >= list.length) {
          return 'path $path: no item $segment.';
        }
        value = list[index];
      case _:
        return 'path $path is not in the screen data.';
    }
  }
  return null;
}

/// The keys from the root of the data to [path], null for a relative path
/// without a list [base].
List<String>? _segments(String path, String? base) {
  if (path.startsWith('/')) {
    return path.split('/').skip(1).toList();
  }
  if (base == null) {
    return null;
  }
  final inItem = path == '.' ? '' : path.replaceFirst('./', '');
  return [
    ...base.split('/').skip(1),
    '0',
    if (inItem.isNotEmpty) ...inItem.split('/'),
  ];
}

final _interpolation = RegExp(r'\$\{([^}]+)\}');

Iterable<String> _childIds(JsonObject? component) => [
  if (component?[A2uiFields.children] case final List<Object?> ids)
    ...ids.whereType<String>(),
  if (component?[A2uiFields.children] case {
    A2uiFields.componentId: final String id,
  })
    id,
  if (component?[A2uiFields.child] case final String id) id,
];
