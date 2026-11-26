/// The name the agent knows a listed method by. `tandem_generator` writes an
/// enum of them for every class with `@TandemAgent()`, such as
/// `OrderCubitTool`, and the session hands its values back. A method whose
/// name the enum cannot use gets a trailing underscore: `_switch` gives
/// `OrderCubitTool.switch_`, and its `value` stays `switch`. One that starts
/// with a digit gets a leading `$`: `_2fa` gives `$2fa`. The build fails when
/// the class's library already declares the enum's name. A schema written by
/// hand declares an enum of its own:
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
