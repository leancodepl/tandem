/// The name the agent knows a listed method by. `tandem_generator` writes an
/// enum of them for every class with `@TandemAgent()`, such as
/// `OrderCubitTool`, and the session hands its values back. A schema written
/// by hand declares an enum of its own:
///
/// ```dart
/// enum ShopTool(@override final String value) implements ToolName {
///   addItem('add_item');
///
///   @override
///   String toString() => value;
/// }
/// ```
// Only an enum implements it, so it has no constructor.
// ignore: use_primary_constructors
abstract interface class ToolName {
  /// The name on the wire, in snake_case.
  String get value;
}
