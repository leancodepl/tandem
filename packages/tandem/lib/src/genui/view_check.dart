import 'dart:math';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/genui/a2ui.dart';
import 'package:tandem/src/genui/catalog.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// What an agent may draw on a screen: A2UI of Tandem's catalog on one
/// surface, the screen's data only by path into what it lists with `.sees`,
/// and buttons only for the methods it lists now, with their parameters.
final class ViewCheck(final AgentListing _listing) {
  /// The most components a view may draw, counting one for every place a
  /// component is drawn and a list template once.
  static const maxComponents = 500;

  /// Why [messages] may not draw, written for the agent to fix them, or
  /// nothing when they may. A message that A2UI itself refuses comes first
  /// and alone. So does a view of more than [maxComponents], which would
  /// take too long to check and to draw.
  List<String> problems(List<Object?> messages) {
    if (_a2uiProblem(messages) case final problem?) {
      return [problem];
    }
    final view = _View.of(messages);
    if (view.surfaceIds.length != 1 || !view.components.containsKey('root')) {
      const oneSurface =
          'Draw one surface: createSurface, then updateComponents with the '
          'same surfaceId and a component with the id "root".';
      return [oneSurface];
    }
    if (view.drawn(upTo: maxComponents) > maxComponents) {
      const tooMany =
          'The view draws more than $maxComponents components, counting one '
          'for every place a component is drawn. Draw fewer.';
      return [tooMany];
    }
    return [
      for (final (:id, :component) in view.buttons)
        ..._buttonProblems(id, component),
      ..._PathCheck(DataModel(_listing.seen), view.components).problems(),
    ];
  }

  static String? _a2uiProblem(List<Object?> messages) {
    final processor = tandemProcessor();
    try {
      processor.processMessages(messages);
      return null;
    } on A2uiError catch (error) {
      return '$error';
    } finally {
      processor.dispose();
    }
  }

  List<String> _buttonProblems(String id, JsonObject button) {
    final event = switch (button[A2uiFields.action]) {
      {A2uiFields.event: final JsonObject event} => event,
      _ => null,
    };
    final method = event?[A2uiFields.name];
    if (event == null || method is! String || !_listing.lists(method)) {
      final methods = _listing.toolNames.join(', ');
      const action =
          '"action": {"event": {"name": <method>, "context": {<parameter>: '
          '<value>}}}';
      return [
        '$id must call a method of the screen: $action. Methods: $methods.',
      ];
    }
    final parameters = _Parameters(_listing.parameters(method));
    final given = switch (event[A2uiFields.context]) {
      final JsonObject context => context.keys.toSet(),
      _ => const <String>{},
    };
    final unknown = given.difference(parameters.names).join(', ');
    final known = parameters.names.join(', ');
    return [
      if (unknown.isNotEmpty)
        '$id: $method has no parameter $unknown. Parameters: $known.',
      for (final missing in parameters.required.difference(given))
        '$id: $method needs $missing.',
    ];
  }
}

/// The components that a view's messages draw, by id, and the surfaces they
/// name.
final class _View._(
  final Map<String, JsonObject> components,
  final Set<Object?> surfaceIds,
) {
  factory of(List<Object?> messages) {
    final components = <String, JsonObject>{};
    final surfaceIds = <Object?>{};
    for (final message in messages) {
      switch (message) {
        case {A2uiFields.createSurface: {A2uiFields.surfaceId: final id}}:
          surfaceIds.add(id);
        case {
          A2uiFields.updateComponents: {
            A2uiFields.surfaceId: final id,
            A2uiFields.components: final List<Object?> drawn,
          },
        }:
          surfaceIds.add(id);
          for (final component in drawn.whereType<JsonObject>()) {
            if (component[A2uiFields.id] case final String id) {
              components[id] = component;
            }
          }
      }
    }
    return ._(components, surfaceIds);
  }

  /// How many components the view draws from its root, counting one for
  /// every place a component is drawn and a list template once, as far as
  /// [upTo] + 1.
  int drawn({required int upTo}) {
    final counts = <String, int>{};
    int count(String id) => counts[id] ??= switch (components[id]) {
      null => 0,
      final component => [
        for (final child in _childIds(component)) count(child),
      ].fold(1, (sum, drawn) => min(sum + drawn, upTo + 1)),
    };
    return count('root');
  }

  Iterable<({String id, JsonObject component})> get buttons => [
    for (final MapEntry(key: id, value: component) in components.entries)
      if (component[A2uiFields.component] == CatalogComponent.button.wireName)
        (id: id, component: component),
  ];
}

/// Checks every data path of a view against the screen's [_data], walking
/// down from the root so that a path inside a list template reads from the
/// list's first item.
final class _PathCheck(
  final DataModel _data,
  final Map<String, JsonObject> _components,
) {
  final _problems = <String>[];

  List<String> problems() {
    _visit('root', base: '/');
    return _problems;
  }

  /// [base] is where relative paths of [id] start, or null inside a list
  /// that is empty now, where no path can be told wrong.
  void _visit(String id, {required String? base}) {
    final component = _components[id];
    if (component == null) {
      return;
    }
    if (base != null) {
      for (final path in _pathsOf(component)) {
        if (!_finds(path, base)) {
          _problems.add('$id: the path $path is not in the screen data.');
        }
      }
    }
    switch (component[A2uiFields.children]) {
      case final List<Object?> children:
        for (final child in children.whereType<String>()) {
          _visit(child, base: base);
        }
      case {
        A2uiFields.componentId: final String template,
        A2uiFields.path: final String path,
      }:
        _visit(template, base: _firstItem(id, path, base: base));
    }
    if (component[A2uiFields.child] case final String child) {
      _visit(child, base: base);
    }
  }

  String? _firstItem(String id, String path, {required String? base}) {
    if (base == null) {
      return null;
    }
    final list = DataModel.resolvePath(path, base);
    if (!_finds(list, '/')) {
      return _notAList(id, path);
    }
    return switch (_data.get(list)) {
      [] => null,
      List<Object?>() => '$list/0',
      _ => _notAList(id, path),
    };
  }

  bool _finds(String path, String base) {
    try {
      return _data.hasPath(DataModel.resolvePath(path, base));
    } on A2uiDataError {
      return false;
    }
  }

  String? _notAList(String id, String path) {
    _problems.add('$id: the path $path is not a list in the screen data.');
    return null;
  }
}

/// The ids of the components that [component] draws: its children, its
/// list template, or its child.
List<String> _childIds(JsonObject component) => [
  ...switch (component[A2uiFields.children]) {
    final List<Object?> children => children.whereType<String>(),
    {A2uiFields.componentId: final String template, A2uiFields.path: _} => [
      template,
    ],
    _ => const <String>[],
  },
  if (component[A2uiFields.child] case final String child) child,
];

/// Every data path that [json] binds, outside the list path of a template:
/// a `{"path": ...}` and each path of a `formatString`, as A2UI reads it.
Iterable<String> _pathsOf(Object? json) => switch (json) {
  {A2uiFields.path: final String path} when json.length == 1 => [path],
  {A2uiFields.componentId: _, A2uiFields.path: _} => const [],
  {
    A2uiFields.call: formatString,
    A2uiFields.args: {A2uiFields.value: final String text},
  } =>
    _pathsOf(_interpolated(text)),
  Map<Object?, Object?>() => json.values.expand(_pathsOf),
  List<Object?>() => json.expand(_pathsOf),
  _ => const [],
};

/// The text and the expressions of [text], or nothing when A2UI cannot read
/// it.
List<Object?> _interpolated(String text) {
  try {
    return ExpressionParser().parse(text);
  } on A2uiExpressionError {
    return const [];
  }
}

/// The JSON Schema of a method's arguments, as far as a button needs it.
extension type const _Parameters(JsonObject? _schema) {
  Set<String> get names => switch (_schema) {
    {'properties': final JsonObject properties} => properties.keys.toSet(),
    _ => const {},
  };

  Set<Object?> get required => switch (_schema) {
    {'required': final List<Object?> required} => required.toSet(),
    _ => const {},
  };
}
