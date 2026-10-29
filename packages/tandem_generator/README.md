# tandem_generator

Generates the code behind the `agentCapabilities` of a class marked `@TandemAgent()`, what the agent sees and which methods it may call, and behind a catalog marked `@TandemCatalog([...])`, the widgets the agent may draw a view with. Run it with `dart run build_runner build`.

Apps depend on [`tandem`](https://pub.dev/packages/tandem) and add this package as a dev dependency. See the [main README](https://github.com/leancodepl/tandem#readme) for how to use it.

Use the same minor version of both: the generated code calls the API of `tandem`. The class can be a Cubit, a Riverpod `Notifier`, a `ChangeNotifier` or any other class. `riverpod_generator` cannot run on the same class, because both write a `_$Name` into the same `.g.dart`.

## Supported types

Tandem describes each type once: the same description gives the JSON Schema of a parameter, writes a result or a `.sees` value as JSON, and reads the agent's arguments back. Any other type fails the build, which names the type and where it is. The first kind that fits decides:

| Dart | JSON | Rules |
| --- | --- | --- |
| `String`, `bool` | string, boolean | |
| `int`, `double`, `num` | integer, number | `15.0` is read as `15`. An `int` refuses `1.5` and any double of magnitude 2^53 or more. |
| `DateTime` | ISO 8601 string | Read with [`DateTime.parse`](https://api.dart.dev/dart-core/DateTime/parse.html), so `2026-10-23` and `2026-10-23T10:20:00Z` both work. A day that does not exist rolls over: `2026-02-30` is 2 March. |
| `Uri` | string | Written with `toString`, read with `Uri.parse`. |
| enum | the value's name | Also with `@JsonValue`: the backend may write `1`, the agent writes `shade`. |
| token class | the member's name | A class without a public constructor whose values are its own `static const` members, such as a design system's text styles. |
| extension type over `String`, `int`, `double`, `num` or `bool` | that value | Built as `Code(value)`, so the unnamed constructor must be public and take only the value, as one positional, non-nullable parameter of the type it wraps. A factory constructor there checks the agent's values too, and throws a `ToolCallRefused` to tell the agent what is wrong. |
| `List<T>`, `Set<T>` | array | A list parameter has no `?` and no default. |
| class | a path, or with `@TandemInput()` an object | A parameter of a class takes an object that a `.sees` holds: the agent writes `{"path": "/customers/1"}`, and the method gets the object at that path, refused when it changed since the agent read it. `@TandemInput()` on the parameter lets the agent write the object field by field. In a `.sees` and a result, the object is written as JSON. Public, not from Dart or Flutter. Built with its public unnamed constructor, whose parameters are all named except at most one, and written through the getters of the same names and types. A generic class is read with its type arguments, so `Page<Customer>` and `Page<Order>` are two types. It needs no `fromJson` or `toJson`, and Tandem ignores them and `@JsonKey`. |

Each type may be nullable. A result may also be `void`, or a `Future` or `FutureOr` of a supported type.

## Converters

A `JsonConverter<T, S>` of `json_annotation`, listed on the annotation, gives a type its form: `@TandemAgent(converters: [IconConverter()])`. It gives one to a type that Tandem cannot read from its declaration, or replaces the one Tandem reads. A value of `T` is written as `S`, which is a type of the table above. Where the agent writes `S`, its schema and description come from `S` and the converter's doc comment. A converter gives a form and does not change where an argument comes from. A parameter of a class that Tandem reads, as the `class` row of the table says, still takes a path to a value that a `.sees` lists, and the agent writes `S` for it only with `@TandemInput()`. For any other type, such as `IconData` or a class with a private constructor, the agent writes `S`. A `FormatException` from `fromJson` refuses the call with the parameter's name and the exception's message; anything else it throws is a bug of the app, and the call fails. A design system exports its converters as a `static const` list, and the app spreads it: `converters: [...Ds.converters, IconConverter()]`.

Tandem has its own converters, which a converter of the app for the same type replaces:

| Type | The agent writes |
| --- | --- |
| `Color` | `#RRGGBB`, or `#RRGGBBAA` with the opacity, as in CSS. 8 bits per channel in sRGB: a color of another color space, such as Display P3, may change slightly. |
| `EdgeInsetsGeometry` | `"16"`, `"8 16"` (top and bottom, then the sides), or sides by name, as `"top 8 start 16"`. `start` and `end` give `EdgeInsetsDirectional`, which follows the reading direction; `left` and `right`, or neither, give `EdgeInsets`. |
| `EdgeInsets`, `EdgeInsetsDirectional` | The same, with only `left` and `right`, or only `start` and `end`. |
| `AlignmentGeometry` | A name of `Alignment`, such as `topLeft`, or of `AlignmentDirectional`, such as `topStart`. |
| `Alignment`, `AlignmentDirectional` | A name of that class. |

A converter matches its type exactly: a parameter of type `EdgeInsets` takes the converter of `EdgeInsets`, not the one of `EdgeInsetsGeometry`. Tandem handles null itself, so a converter converts a type without `?`, and one such as `JsonConverter<Uri?, String?>` fails the build. Two converters for one type fail the build.

## Catalogs

`@TandemCatalog([...])` on a class lists widget classes, and the class's `_$Name` mixin describes each as a component: its name, the first paragraph of its doc comment, and its constructor's parameters as properties.

| Parameter | The agent writes |
| --- | --- |
| `Widget`, `Widget?` | the id of another component |
| `List<Widget>` | ids, or one component for every item of a list in the data |
| `VoidCallback`, `VoidCallback?` | an action that calls a listed method |
| `ValueChanged<T>`, `ValueChanged<T>?` | a field: an action whose method gets what the user enters, a `T` |
| `Key`, `FocusNode`, a `ChangeNotifier` such as a controller | nothing: the widget keeps its default |
| any other type | a value by the rule above, or a path into the data |

A widget without a doc comment fails the build. A required parameter of a type without a form fails the build and names the converter to add; an optional one keeps the widget's default, with one line in the build. A default that is not a literal, an enum value or a static const member of its own class, such as `Alignment.center`, also keeps the widget's default. The widget's class must be visible where the catalog is, and Tandem reads a parameter's type from the widget's getter of the same name; without one, the type must be visible there too.

The catalog's doc comment gives the agent its guidelines and one example view, a ```json block of `components`. The build checks the example's component and property names; `TandemView` checks its paths and methods against the screen in debug.

A catalog belongs to one screen, because its guidelines and example name that screen's data and methods. Another screen that draws with the same widgets declares its own catalog from the same list, as `@TandemCatalog([...DesignSystem.components])`, with its own guidelines and example.

## Missing, null and default

| The agent | `int count = 1` | `String? note = 'new'` | `String? note` |
| --- | --- | --- | --- |
| leaves it out | `1` | `'new'` | `null` |
| sends `null` | refused | `null` | `null` |

The schema of a nullable parameter is `anyOf` the schema of its type and `{"type": "null"}`, so the agent knows it may send `null`. That is plain JSON Schema, which ag-ui-adk 0.9.0 converts for Gemini. A list of types, the shorter form, fails in ag-ui-adk 0.9.0. A parameter that is neither nullable nor has a default is required. A default is a `bool`, `int`, `double` or `String` constant, an enum value, a `static const` member of its own class, such as `Alignment.center`, or `null`.

A refused call does not run the method. The agent gets a message that names the argument, also for a wrong type or a key the schema does not have.

## Anything else

Maps, records, sealed classes, `Duration`, `BigInt` and methods with type parameters are not supported. List a thin method that takes supported types and calls the real one:

```dart
/// Sets how long the delivery may take, in [minutes].
void setDeliveryWindow(int minutes) => setWindow(Duration(minutes: minutes));
```

In the same way, `.sees` can take a getter that returns a plain class made for the agent.

## AI

This package is written with AI assistance and reviewed by hand.
