import 'package:flutter/widgets.dart';
import 'package:tandem/src/agent_list.dart';
import 'package:tandem/src/agent_paths.dart';
import 'package:tandem/src/agent_type.dart';
import 'package:tandem/src/genui/action_arguments.dart';
import 'package:tandem/src/genui/agent_catalog.dart';
import 'package:tandem/src/genui/view_check.dart';
import 'package:tandem/src/report.dart';

/// Whether a method of an action can run now.
enum ActionState() {
  /// The screen does not list it: a component that needs it is left out.
  unlisted,

  /// It is listed, but cannot run now, such as while another action of the
  /// view runs or a method that needs approval while the agent thinks.
  waiting,

  available,
}

/// What a view asks of the screen for its actions.
abstract interface class ViewActions() {
  ActionState stateOf(String method, {required bool field});

  /// Calls [method] with [arguments], whose paths are absolute and point at
  /// values of [seen], the data the view was drawn with.
  void call(
    String method,
    Map<String, ViewArgument> arguments,
    AgentListing seen, {
    FieldEntry? entry,
  });
}

/// Draws the components of [_view] with the values of [_listing], the
/// screen's data now. A component whose required value or action is
/// missing now is left out until it is back.
final class ViewRender(
  final DrawnComponents _view,
  final AgentListing _listing,
  final ViewActions _actions,
) {
  late final _roots = _listing.roots;

  /// How many components [view] draws on the data of [listing], as far as
  /// [upTo] + 1.
  static int count(
    DrawnComponents view,
    AgentListing listing, {
    int upTo = ViewCheck.maxComponents,
  }) {
    final roots = listing.roots;
    var count = 0;
    void visit(DrawnComponent component, _Place place) {
      if (count > upTo) return;
      count++;
      for (final property in component.properties) {
        switch (property) {
          case ChildId(:final id):
            visit(view[id], place);
          case ChildIds(:final ids):
            for (final id in ids) {
              if (count > upTo) return;
              visit(view[id], place);
            }
          case ChildTemplate(:final template, :final path):
            for (final item in place.items(path, roots)) {
              if (count > upTo) return;
              visit(view[template], item);
            }
          default:
        }
      }
    }

    visit(view.root, const _Place.root());
    return count;
  }

  /// The widget of the root, or null when it is left out.
  Widget? build() => _build(_view.root, const _Place.root(), slot: '');

  /// [slot] tells apart two places of one component under one parent.
  Widget? _build(
    DrawnComponent component,
    _Place place, {
    required String slot,
  }) {
    final args = _Args();
    for (final drawn in component.properties) {
      final ready = switch (drawn) {
        LiteralValue(:final property, :final json) => _value(
          args,
          property,
          _literal(property, json),
        ),
        BoundValue(:final property, :final path) => _value(
          args,
          property,
          property.fit(place.locate(path, _roots).value),
        ),
        ChildId(:final property, :final id) => _child(
          args,
          property,
          id,
          place,
        ),
        ChildIds(:final property, :final ids) => _children(args, property, [
          for (final (index, id) in ids.indexed)
            ?_build(_view[id], place, slot: '${property.name}$index'),
        ]),
        ChildTemplate(:final property, :final template, :final path) =>
          _children(args, property, [
            for (final item in place.items(path, _roots))
              ?_build(_view[template], item, slot: property.name),
          ]),
        PressAction(:final property, :final action) => _press(
          args,
          property,
          _Action.of(action, place),
        ),
        FieldAction(:final property, :final action) => _field(
          args,
          property,
          _Action.of(action, place),
        ),
      };
      if (!ready) return null;
    }
    return KeyedSubtree(
      key: ValueKey('${component.id}@${place.key}#$slot'),
      child: component.component.build(args),
    );
  }

  bool _value(_Args args, ValueProperty<Object?> property, Object? value) {
    if (value == AgentType.absent) return !property.required;
    args.values[property.name] = value;
    return true;
  }

  /// The literal [json] of [property], or [AgentType.absent] when a
  /// converter of the app fails on it, a bug that is reported.
  Object? _literal(ValueProperty<Object?> property, Object? json) {
    try {
      return property.fit(
        property.type.read(json, const AgentReading('', objects: .refused)),
      );
    } catch (err, st) {
      report(err, st);
      return AgentType.absent;
    }
  }

  bool _child(_Args args, ChildProperty property, String id, _Place place) {
    args.widgets[property.name] = _build(_view[id], place, slot: property.name);
    return true;
  }

  bool _children(_Args args, ChildrenProperty property, List<Widget> children) {
    args.lists[property.name] = children;
    return true;
  }

  bool _press(_Args args, PressProperty property, _Action? action) {
    final state = _stateOf(action, field: false);
    if (action == null || state == .unlisted) return !property.required;
    args.callbacks[property.name] = switch (state) {
      .available => () => _actions.call(
        action.method,
        action.arguments,
        _listing,
      ),
      _ when property.required => _refused,
      _ => null,
    };
    return true;
  }

  bool _field(_Args args, FieldProperty<Object?> property, _Action? action) {
    final state = _stateOf(action, field: true);
    if (action == null || state == .unlisted) return !property.required;
    args.callbacks[property.name] = switch (state) {
      .available => property.callback(
        (entry) => _actions.call(
          action.method,
          action.arguments,
          _listing,
          entry: FieldEntry(property.type, entry),
        ),
      ),
      _ when property.required => property.callback((_) {}),
      _ => null,
    };
    return true;
  }

  /// The state of [action], unlisted also while a value its arguments read
  /// is missing, or null for a parameter that takes no null, as for a
  /// component's required value.
  ActionState _stateOf(_Action? action, {required bool field}) {
    if (action == null || !_hasValues(action)) return .unlisted;
    return _actions.stateOf(action.method, field: field);
  }

  bool _hasValues(_Action action) {
    final tool = _listing.toolNamed(action.method);
    final types = {
      for (final parameter in [...?tool?.parameters])
        parameter.name: parameter.type,
    };
    return action.arguments.entries.every(
      (argument) => switch (argument) {
        MapEntry(:final key, value: PathArgument(:final path)) =>
          switch (DataPath.jsonAt(_roots, path)) {
            AgentType.absent => false,
            null => types[key]?.isNullable ?? true,
            _ => true,
          },
        _ => true,
      },
    );
  }

  // A required callback of a widget cannot be null: it refuses while its
  // method cannot run, and the next frame enables it again.
  static void _refused() {}
}

/// Where a component is drawn: the root of the data, or an item of a list
/// with its absolute path.
final class const _Place._(
  final List<String> base,
  final AgentType<Object?>? type,
  final Object? value,
) {
  const new root() : this._(const [], null, AgentType.absent);

  String get key => base.join('/');

  List<String> absolute(String path) => DataPath.resolve(path, base: base);

  /// The type and the value at [path], absolute or from here, below
  /// [roots].
  ({AgentType<Object?>? type, Object? value}) locate(
    String path,
    Map<String, PathValue> roots,
  ) {
    if (DataPath.segments(path) case final segments?) {
      if (segments.isEmpty) return (type: null, value: AgentType.absent);
      final found = DataPath.locate(roots, segments);
      return (type: found?.type, value: found?.value ?? AgentType.absent);
    }
    var type = this.type;
    var value = this.value;
    for (final segment in DataPath.relative(path)) {
      final next = type?.typeAt(segment);
      value = switch (type) {
        final type? when value != AgentType.absent => type.valueAt(
          value,
          segment,
        ),
        _ => AgentType.absent,
      };
      type = next;
    }
    return (type: type, value: value);
  }

  /// A place for each item of the list at [path] below [roots].
  Iterable<_Place> items(String path, Map<String, PathValue> roots) sync* {
    final (:type, :value) = locate(path, roots);
    final item = type?.itemType;
    if (type == null || item == null || value == AgentType.absent) return;
    final list = absolute(path);
    for (var index = 0; ; index++) {
      final itemValue = type.valueAt(value, '$index');
      if (itemValue == AgentType.absent) return;
      yield ._([...list, '$index'], item, itemValue);
    }
  }
}

/// The method of an action and its arguments, each path made absolute so
/// that it reads the data the view was drawn with.
final class const _Action._(
  final String method,
  final Map<String, ViewArgument> arguments,
) {
  static _Action? of(ViewAction? action, _Place place) => switch (action) {
    ViewAction(:final method, :final context) => ._(method, {
      for (final MapEntry(:key, :value) in (context ?? const {}).entries)
        key: switch (value) {
          PathArgument(:final path) => PathArgument(
            '/${place.absolute(path).join('/')}',
          ),
          _ => value,
        },
    }),
    null => null,
  };
}

final class _Args() implements ComponentArgs {
  final values = <String, Object?>{};
  final widgets = <String, Widget?>{};
  final lists = <String, List<Widget>>{};
  final callbacks = <String, Function?>{};

  @override
  T value<T>(String name) => values[name] as T;

  @override
  T valueOr<T>(String name, T fallback) =>
      values.containsKey(name) ? values[name] as T : fallback;

  @override
  Widget child(String name) => widgets[name] ?? const SizedBox.shrink();

  @override
  Widget? childOrNull(String name) => widgets[name];

  @override
  List<Widget> children(String name) => lists[name] ?? const [];

  @override
  VoidCallback press(String name) => pressOrNull(name) ?? ViewRender._refused;

  @override
  VoidCallback? pressOrNull(String name) => switch (callbacks[name]) {
    final VoidCallback callback => callback,
    _ => null,
  };

  @override
  ValueChanged<T> field<T>(String name) => fieldOrNull(name) ?? (_) {};

  @override
  ValueChanged<T>? fieldOrNull<T>(String name) => switch (callbacks[name]) {
    final ValueChanged<T> callback => callback,
    _ => null,
  };
}
