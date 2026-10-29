import 'dart:convert';

import 'package:tandem/src/agent_paths.dart';
import 'package:tandem/src/agent_schema.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/errors.dart';
import 'package:tandem/src/genui/agent_catalog.dart';
import 'package:tandem/src/protocol/ag_ui.dart';

/// The types of the values a view may read, by the name of their `.sees`,
/// and the methods its actions may call.
typedef ViewData = ({
  Map<String, AgentType<Object?>> roots,
  Map<String, ({AgentTool tool, bool needsApproval})> methods,
});

/// What the agent may draw: components of the app's catalog, the screen's
/// data by path into what it lists with `.sees`, and actions only for the
/// methods it lists, with their parameters.
final class ViewCheck(final AgentCatalog _catalog, final ViewData _data) {
  /// The most components a view draws, counting one for every place a
  /// component is drawn, the items of a list too.
  static const maxComponents = 500;

  /// [components] parsed once, and why they may not draw, one line for
  /// each problem, written for the agent to fix them, or nothing when they
  /// may.
  ({DrawnComponents view, List<String> problems}) check(Object? components) {
    final view = DrawnComponents.parse(components, _catalog);
    if (view.problems.isNotEmpty) {
      return (
        view: view,
        problems: [...view.problems, ...view.propertyProblems],
      );
    }
    final scopes = view.scopes(_data);
    return (
      view: view,
      problems: [
        ...view.propertyProblems,
        for (final MapEntry(key: component, value: places) in scopes.entries)
          for (final scope in places) ..._componentProblems(component, scope),
      ],
    );
  }

  List<String> _componentProblems(DrawnComponent component, ViewScope scope) {
    final problems = <String>[];
    for (final drawn in component.properties) {
      final at = '${component.id}.${drawn.property.name}';
      problems.addAll(switch (drawn) {
        LiteralValue(:final property, :final json) => _literalProblems(
          at,
          json,
          property.type,
          scope,
        ),
        BoundValue(:final property, :final path) => _pathProblems(
          at,
          path,
          property.type,
          scope,
        ),
        ChildId() || ChildIds() => const [],
        ChildTemplate(:final path) => _listProblems(at, path, scope),
        PressAction(:final action) => _actionProblems(
          at,
          action,
          scope,
          input: null,
        ),
        FieldAction(:final property, :final action) => _actionProblems(
          at,
          action,
          scope,
          input: property.type,
        ),
      });
    }
    return problems;
  }

  List<String> _literalProblems(
    String at,
    Object? json,
    AgentType<Object?> type,
    ViewScope scope,
  ) {
    try {
      type.read(json, AgentReading(at, objects: .refused));
      return const [];
    } on ToolCallRefused catch (refusal) {
      if (type.isObject) {
        final fitting = scope.pathsOf(type, _data.roots);
        final example = fitting.isEmpty ? '' : ', such as ${fitting.first}';
        final problem =
            '$at: write a path to a ${type.name} the screen lists$example, '
            'not an object.';
        return [problem];
      }
      return [refusal.message];
    }
  }

  List<String> _listProblems(String at, String path, ViewScope scope) {
    if (scope.item(path, _data.roots) != null) return const [];
    final found = scope.typeAt(path, _data.roots);
    if (found == null) {
      return [
        '$at: $path is not in the data. ${scope.hint(path, _data.roots)}',
      ];
    }
    return ['$at: $path is a ${found.name}, not a list.'];
  }

  List<String> _pathProblems(
    String at,
    String path,
    AgentType<Object?> type,
    ViewScope scope,
  ) {
    final found = scope.typeAt(path, _data.roots);
    if (found == null) {
      return [
        '$at: $path is not in the data. ${scope.hint(path, _data.roots)}',
      ];
    }
    if (type.accepts(found)) return const [];
    final fitting = scope.pathsOf(type, _data.roots);
    final paths = fitting.isEmpty
        ? 'The data has none.'
        : 'Paths of that type: ${fitting.join(', ')}.';
    final names = '${found.nameBeside(type)}, not a ${type.nameBeside(found)}';
    return ['$at: $path is a $names. $paths'];
  }

  List<String> _actionProblems(
    String at,
    ViewAction? action,
    ViewScope scope, {
    required AgentType<Object?>? input,
  }) {
    final methods = _data.methods.keys.join(', ');
    final method = _data.methods[action?.method];
    if (action == null || method == null) {
      const shape =
          '{"action": {"event": {"name": <method>, "context": '
          '{<parameter>: <value>}}}}';
      return [
        '$at: must call a method of the screen, as $shape. Methods: $methods.',
      ];
    }
    final name = action.method;
    if (input != null && method.needsApproval) {
      final calls = [
        for (final MapEntry(:key, :value) in _data.methods.entries)
          if (!value.needsApproval) key,
      ].join(', ');
      return [
        '$at calls $name, which needs approval. A field calls only $calls.',
      ];
    }
    final context = action.context;
    if (context == null) {
      return ['$at: "context" is an object of the arguments of $name.'];
    }
    final parameters = {
      for (final parameter in method.tool.parameters) parameter.name: parameter,
    };
    final problems = <String>[];
    var inputs = 0;
    for (final MapEntry(key: argument, :value) in context.entries) {
      final parameter = parameters[argument];
      if (parameter == null) {
        problems.add(
          '$at: $name has no parameter $argument. Parameters: '
          '${parameters.keys.join(', ')}.',
        );
        continue;
      }
      problems.addAll(
        _argumentProblems('$at.$argument', value, parameter, scope, input),
      );
      if (value is InputArgument) inputs++;
    }
    for (final parameter in parameters.values) {
      if (parameter.required && !context.containsKey(parameter.name)) {
        problems.add('$at: $name needs ${parameter.name}.');
      }
    }
    if (input != null && inputs != 1) {
      problems.add(
        '$at: a field puts {"input": true} in one argument of $name, where '
        'the entry goes.',
      );
    }
    return problems;
  }

  List<String> _argumentProblems(
    String at,
    ViewArgument argument,
    AgentParameter<Object?> parameter,
    ViewScope scope,
    AgentType<Object?>? input,
  ) {
    final type = parameter.type;
    switch (argument) {
      case InputArgument():
        if (input == null) return ['$at: only a field puts {"input": true}.'];
        // An entry of null would only be refused when the user enters it.
        if (!type.accepts(input) || (input.isNullable && !type.isNullable)) {
          final names =
              '${input.nameBeside(type)}, not a '
              '${type.nameBeside(input)}';
          return ['$at: the field enters a $names.'];
        }
        // The agent writes the objects of an input parameter, so the entry
        // goes in as it is.
        if (input.holdsObject && !parameter.input) {
          final problem =
              '$at: the field enters a ${input.name}, whose objects '
              '${parameter.name} takes only by path.';
          return [problem];
        }
        return const [];
      case PathArgument(:final path):
        return _pathProblems(at, path, type, scope);
      case ValueArgument(:final json):
        try {
          type.read(
            json,
            AgentReading(at, objects: parameter.input ? .fields : .refused),
          );
          return const [];
        } on ToolCallRefused catch (refusal) {
          return [refusal.message];
        }
    }
  }
}

/// The components of a view by id, parsed once from what the agent wrote:
/// each with its component of the catalog and the properties it sets.
final class DrawnComponents._(
  final Map<String, DrawnComponent> _byId,

  /// What keeps the view from being read at all: its shape, an unknown
  /// component, a missing or circular reference.
  final List<String> problems,

  /// The properties a component does not have, misses or writes in another
  /// shape.
  final List<String> propertyProblems,
) {
  factory parse(Object? components, AgentCatalog catalog) {
    if (components is! List<Object?>) {
      return ._(const {}, const [_shape], const []);
    }
    final byName = {
      for (final component in catalog.components) component.name: component,
    };
    final ids = <String>{};
    final byId = <String, DrawnComponent>{};
    final problems = <String>[];
    final propertyProblems = <String>[];
    for (final item in components) {
      if (item case {'id': final String id, 'component': final String name}
          when item is JsonObject) {
        if (!ids.add(id)) {
          problems.add('$id: two components have this id.');
          continue;
        }
        final component = byName[name];
        if (component == null) {
          problems.add(
            '$id: no component $name. Components: ${byName.keys.join(', ')}.',
          );
          continue;
        }
        final drawn = DrawnComponent._parse(id, item, component);
        byId[id] = drawn.component;
        propertyProblems.addAll(drawn.problems);
      } else {
        problems.add(
          'Each component needs a string "id" and a "component": '
          '${jsonEncode(item)}.',
        );
      }
    }
    if (!ids.contains('root')) {
      problems.add('One component has the id "root".');
    }
    final view = DrawnComponents._(byId, problems, propertyProblems);
    if (problems.isEmpty) problems.addAll(view._graphProblems());
    return view;
  }

  static const _shape =
      'Pass "components": a JSON array of components, each with an "id" and '
      'a "component".';

  DrawnComponent get root => this['root'];

  /// The component [id], which a view without [problems] has for every id
  /// that a component draws.
  DrawnComponent operator [](String id) =>
      _byId[id] ?? (throw StateError('No component has the id $id.'));

  /// The places where each component reached from the root is drawn: the
  /// root of the data, or an item of a list, one for each template that
  /// leads to it.
  // Once per component and place: a component that many parents draw is
  // visited once, not once for every way to reach it.
  Map<DrawnComponent, List<ViewScope>> scopes(ViewData data) {
    final scopes = <DrawnComponent, Map<String, ViewScope>>{};
    void visit(DrawnComponent component, ViewScope scope) {
      final here = scopes.putIfAbsent(component, () => {});
      if (here.containsKey(scope.key)) return;
      here[scope.key] = scope;
      for (final property in component.properties) {
        switch (property) {
          case ChildId(:final id):
            visit(this[id], scope);
          case ChildIds(:final ids):
            for (final id in ids) {
              visit(this[id], scope);
            }
          case ChildTemplate(:final template, :final path):
            if (scope.item(path, data.roots) case final item?) {
              visit(this[template], item);
            }
          default:
        }
      }
    }

    visit(root, const ViewScope.root());
    return {
      for (final MapEntry(:key, :value) in scopes.entries)
        key: [...value.values],
    };
  }

  List<String> _graphProblems() {
    final problems = <String>[];
    for (final component in _byId.values) {
      for (final child in component.childIds) {
        if (!_byId.containsKey(child)) {
          problems.add('${component.id}: no component has the id $child.');
        }
      }
    }
    if (problems.isNotEmpty) return problems;
    final visiting = <String>{};
    final done = <String>{};
    bool cycles(String id) {
      if (done.contains(id)) return false;
      if (!visiting.add(id)) return true;
      final found = this[id].childIds.any(cycles);
      visiting.remove(id);
      done.add(id);
      return found;
    }

    for (final id in _byId.keys) {
      if (cycles(id)) {
        return ['$id: draws itself through its children.'];
      }
    }
    return const [];
  }
}

/// One component of a view: its [component] of the catalog and the
/// properties the agent set, in the catalog's order, without a null.
final class const DrawnComponent._(
  final String id,
  final AgentComponent component,
  final List<DrawnProperty> properties,
) {
  /// The component [json] as [component], and what does not fit it.
  static ({DrawnComponent component, List<String> problems}) _parse(
    String id,
    JsonObject json,
    AgentComponent component,
  ) {
    final names = [for (final p in component.properties) p.name];
    final problems = [
      for (final key in json.keys)
        if (key != 'id' && key != 'component' && !names.contains(key))
          '$id: ${component.name} has no "$key". Properties: ${names.join(', ')}.',
      for (final property in component.properties)
        if (property.required && json[property.name] == null)
          '$id: ${component.name} needs "${property.name}".',
    ];
    final properties = <DrawnProperty>[];
    for (final property in component.properties) {
      final value = json[property.name];
      if (value == null) continue;
      if (DrawnProperty._parse(property, value) case final drawn?) {
        properties.add(drawn);
      } else {
        problems.add(_shapeProblem('$id.${property.name}', property));
      }
    }
    return (component: ._(id, component, properties), problems: problems);
  }

  /// The ids it draws: its children, the template of its list, and its
  /// child.
  Iterable<String> get childIds sync* {
    for (final property in properties) {
      switch (property) {
        case ChildId(:final id):
          yield id;
        case ChildIds(:final ids):
          yield* ids;
        case ChildTemplate(:final template):
          yield template;
        default:
      }
    }
  }

  static String _shapeProblem(String at, AgentProperty property) =>
      switch (property) {
        ChildProperty() => '$at: write the id of a component.',
        _ =>
          '$at: write a list of ids, or {"componentId": <id>, "path": <path '
              'of a list>}.',
      };
}

/// A property that a component of a view sets, as the agent wrote it.
sealed class const DrawnProperty() {
  AgentProperty get property;

  /// [json], the value of [property], or null when a child or children are
  /// written in another shape.
  static DrawnProperty? _parse(AgentProperty property, Object json) => switch ((
    property,
    json,
  )) {
    (final ValueProperty<Object?> property, {'path': final String path})
        when json is Map && json.length == 1 =>
      BoundValue(property, path),
    (final ValueProperty<Object?> property, _) => LiteralValue(property, json),
    (final ChildProperty property, final String id) => ChildId(property, id),
    (final ChildrenProperty property, final List<Object?> ids)
        when ids.every((id) => id is String) =>
      ChildIds(property, [...ids.whereType<String>()]),
    (
      final ChildrenProperty property,
      {'componentId': final String template, 'path': final String path},
    )
        when json is Map && json.length == 2 =>
      ChildTemplate(property, template, path),
    (final PressProperty property, _) => PressAction(
      property,
      ViewAction.parse(json),
    ),
    (final FieldProperty<Object?> property, _) => FieldAction(
      property,
      ViewAction.parse(json),
    ),
    _ => null,
  };
}

/// A value the agent wrote itself.
final class const LiteralValue(
  @override final ValueProperty<Object?> property,
  final Object? json,
) extends DrawnProperty;

/// A value of the data, `{"path": <path>}`.
final class const BoundValue(
  @override final ValueProperty<Object?> property,
  final String path,
) extends DrawnProperty;

final class const ChildId(
  @override final ChildProperty property,
  final String id,
) extends DrawnProperty;

final class const ChildIds(
  @override final ChildrenProperty property,
  final List<String> ids,
) extends DrawnProperty;

/// The component [template] for every item of the list at [path].
final class const ChildTemplate(
  @override final ChildrenProperty property,
  final String template,
  final String path,
) extends DrawnProperty;

/// The action of a press, null when it names no method.
final class const PressAction(
  @override final PressProperty property,
  final ViewAction? action,
) extends DrawnProperty;

/// The action of a field, null when it names no method.
final class const FieldAction(
  @override final FieldProperty<Object?> property,
  final ViewAction? action,
) extends DrawnProperty;

/// The action of a press or a field, as the agent writes it:
/// `{"action": {"event": {"name": <method>, "context": {...}}}}`.
final class const ViewAction._(
  final String method,

  /// The arguments by parameter, or null when "context" is not an object.
  final Map<String, ViewArgument>? context,
) {
  /// [json] as an action, or null when it names no method.
  static ViewAction? parse(Object? json) {
    if (json case {'action': {'event': final JsonObject event}}) {
      if (event['name'] case final String method) {
        return ._(method, switch (event['context']) {
          final JsonObject context => {
            for (final MapEntry(:key, :value) in context.entries)
              key: ViewArgument.parse(value),
          },
          null => const {},
          _ => null,
        });
      }
    }
    return null;
  }
}

/// An argument of an action as the agent writes it: `{"path": <path>}` for
/// a value of the data, `{"input": true}` for the entry of a field, or the
/// value itself. Only an object with that one key is a path or the entry.
sealed class const ViewArgument() {
  factory parse(Object? json) => switch (json) {
    {'path': final String path} when json.length == 1 => PathArgument(path),
    {'input': true} when json.length == 1 => const InputArgument(),
    _ => ValueArgument(json),
  };
}

final class const PathArgument(final String path) extends ViewArgument;

final class const InputArgument() extends ViewArgument;

final class const ValueArgument(final Object? json) extends ViewArgument;

/// Where a component is drawn: the root of the data, or an item of a list
/// in it, of the type [type]. A path without a leading `/` starts at the
/// item, and `""` is the item itself.
final class const ViewScope._(
  /// The segments of the item's path, `<i>` for each list.
  final List<String> base,
  final AgentType<Object?>? type,
) {
  const new root() : this._(const [], null);

  String get key => base.join('/');

  /// The type of [path] here, or null when the data has no such place.
  AgentType<Object?>? typeAt(
    String path,
    Map<String, AgentType<Object?>> roots,
  ) {
    final (:start, :segments) = _start(path, roots);
    var type = start;
    for (final segment in segments) {
      type = type?.typeAt(segment);
    }
    return type;
  }

  /// The scope of the items of the list at [path], or null when it is not a
  /// list.
  ViewScope? item(String path, Map<String, AgentType<Object?>> roots) {
    final item = typeAt(path, roots)?.itemType;
    if (item == null) return null;
    return ._([...absolute(path), '<i>'], item);
  }

  /// The segments of [path] from the root of the data.
  List<String> absolute(String path) => DataPath.resolve(path, base: base);

  /// The paths whose type [type] accepts, here and from the root.
  List<String> pathsOf(
    AgentType<Object?> type,
    Map<String, AgentType<Object?>> roots,
  ) => [
    if (this.type case final item? when type.accepts(item)) '',
    ...DataPath.pathsOf(roots, type),
  ];

  /// What the data has near [path], for a refusal.
  String hint(String path, Map<String, AgentType<Object?>> roots) {
    final segments = absolute(path);
    for (var length = segments.length - 1; length > 0; length--) {
      final parent = '/${segments.take(length).join('/')}';
      final fields = const ViewScope.root().typeAt(parent, roots)?.fieldNames;
      if (fields != null && fields.isNotEmpty) {
        return 'Paths under $parent: ${fields.join(', ')}.';
      }
    }
    return 'Paths: ${roots.keys.map((name) => '/$name').join(', ')}.';
  }

  ({AgentType<Object?>? start, List<String> segments}) _start(
    String path,
    Map<String, AgentType<Object?>> roots,
  ) {
    if (DataPath.segments(path) case final segments?) {
      if (segments.isEmpty) return (start: null, segments: const []);
      return (
        start: roots[segments.first],
        segments: segments.skip(1).toList(),
      );
    }
    return (start: type, segments: DataPath.relative(path));
  }
}
