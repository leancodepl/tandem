import 'package:flutter/widgets.dart';
import 'package:tandem/src/agent_type.dart';

/// The widgets the agent may draw a view with. The `_$Name` mixin that
/// `tandem_generator` writes for a class with `@TandemCatalog([...])`
/// implements it, from each widget's constructor and doc comment.
// The experimental lint asks for a primary constructor on an interface too.
// ignore: use_primary_constructors
abstract interface class AgentCatalog {
  /// One for every widget of the catalog.
  List<AgentComponent> get components;

  /// The catalog's doc comment without its example: how the agent should
  /// draw with these components.
  String get guidelines;

  /// The example view of the catalog's doc comment, its `components`.
  List<Map<String, Object?>> get example;
}

/// One widget of a catalog, as the generated code describes it.
final class AgentComponent<W extends Widget>._(
  /// The widget's class name, which the agent writes as `component`.
  final String name,

  /// The first paragraph of the widget's doc comment.
  final String description,

  /// One for every constructor parameter the agent may set.
  final List<AgentProperty> properties,

  /// Builds the widget from the properties of one component of a view.
  final W Function(ComponentArgs args) build,
) {
  /// Called by the generated code: `properties` names each parameter with its
  /// getter, as `property('title', (widget) => widget.title)`, and says what
  /// it is, as `.value(.string)` or `.press()`.
  factory of({
    required String name,
    required String description,
    required List<AgentProperty> Function(AgentProperties<W> property)
    properties,
    required W Function(ComponentArgs args) build,
  }) => ._(name, description, properties(AgentProperties<W>._()), build);

  /// The property [name], or null when the component has none.
  AgentProperty? property(String name) =>
      properties.where((property) => property.name == name).firstOrNull;
}

/// Makes the properties of an [AgentComponent].
final class AgentProperties<W>._() {
  /// A value of the parameter [name], typed by its getter [get], as
  /// `property('title', (widget) => widget.title).value(.string)`. Without a
  /// getter, give the type: `property<String>('title')`.
  AgentPropertyOf<F> call<F>(String name, [F Function(W widget)? get]) =>
      AgentPropertyOf<F>._(name);

  /// A `Widget`: the id of another component.
  AgentProperty child(String name, {bool required = true}) =>
      ChildProperty._(name, required: required);

  /// A `List<Widget>`: ids of components, or one component for every item of
  /// a list in the data.
  AgentProperty children(String name, {bool required = true}) =>
      ChildrenProperty._(name, required: required);

  /// A `VoidCallback`: an action that calls a method of the screen.
  AgentProperty press(String name, {bool required = true}) =>
      PressProperty._(name, required: required);

  /// A `ValueChanged<V>`, typed by its getter [get]: an action whose method
  /// gets what the user enters. `.as(type)` gives the type of the entry.
  AgentFieldPropertyOf<V> field<V>(
    String name, [
    ValueChanged<V>? Function(W widget)? get,
  ]) => AgentFieldPropertyOf<V>._(name);
}

/// A value parameter of a widget, waiting for its type.
final class AgentPropertyOf<F>._(final String _name) {
  /// A value of [type], which the agent writes or binds to a path. Without
  /// [required], the agent may leave it out.
  AgentProperty value(AgentType<F> type, {bool required = true}) =>
      ValueProperty._(_name, type, required: required);
}

/// A field parameter of a widget, waiting for the type of its entry.
final class AgentFieldPropertyOf<V>._(final String _name) {
  /// An entry of [type]. Without [required], the agent may leave the field
  /// out.
  AgentProperty as(AgentType<V> type, {bool required = true}) =>
      FieldProperty<V>._(_name, type, required: required);
}

/// One parameter of a widget that the agent sets in a view.
sealed class AgentProperty() {
  String get name;

  /// Whether the agent must set it: its parameter is neither nullable nor
  /// has a default value.
  bool get required;
}

/// A value: a literal of [type], or a path into the data.
final class ValueProperty<T>._(
  @override final String name,
  final AgentType<T> type, {
  @override required final bool required,
}) extends AgentProperty;

/// A `Widget`: the id of another component.
final class ChildProperty._(
  @override final String name, {
  @override required final bool required,
}) extends AgentProperty;

/// A `List<Widget>`: ids, or a template for every item of a list.
final class ChildrenProperty._(
  @override final String name, {
  @override required final bool required,
}) extends AgentProperty;

/// A `VoidCallback`: an action.
final class PressProperty._(
  @override final String name, {
  @override required final bool required,
}) extends AgentProperty;

/// A `ValueChanged<T>`: an action with what the user enters.
final class FieldProperty<T>._(
  @override final String name,
  final AgentType<T> type, {
  @override required final bool required,
}) extends AgentProperty;

/// The properties of one component of a view, as the widget's constructor
/// takes them. The generated `build` reads them; the view gives only a
/// value that is there, so a required one is always there.
abstract interface class ComponentArgs() {
  /// The value of [name], null when it has none.
  T value<T>(String name);

  /// The value of [name], or [fallback], the parameter's default, when the
  /// view does not set it now.
  T valueOr<T>(String name, T fallback);

  Widget child(String name);

  Widget? childOrNull(String name);

  List<Widget> children(String name);

  VoidCallback press(String name);

  VoidCallback? pressOrNull(String name);

  ValueChanged<T> field<T>(String name);

  ValueChanged<T>? fieldOrNull<T>(String name);
}
