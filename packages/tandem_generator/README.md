# tandem_generator

Generates the code behind the `agentCapabilities` of a class marked `@TandemAgent()`: what the agent sees and which methods it may call. Run it with `dart run build_runner build`.

Apps depend on [`tandem`](https://pub.dev/packages/tandem) and add this package as a dev dependency. See the [main README](https://github.com/leancodepl/tandem#readme) for how to use it.

Use the same minor version of both: the generated code calls the API of `tandem`. The class can be a Cubit, a Riverpod `Notifier`, a `ChangeNotifier` or any other class. `riverpod_generator` cannot run on the same class, because both write a `_$Name` into the same `.g.dart`.

## Supported types

The parameters of the listed methods become the JSON Schema the agent fills in. Results and `.sees` getters reach the agent as JSON. Any other type fails the build, which names the type and where it is.

| Dart | JSON | Rules |
| --- | --- | --- |
| `String`, `bool` | string, boolean | |
| `int`, `double`, `num` | integer, number | `15.0` is read as `15`. An `int` refuses `1.5` and any double of magnitude 2^53 or more. |
| `DateTime` | ISO 8601 string | Read with [`DateTime.parse`](https://api.dart.dev/dart-core/DateTime/parse.html), so `2026-10-23` and `2026-10-23T10:20:00Z` both work. A day that does not exist rolls over: `2026-02-30` is 2 March. |
| enum | the value's name | |
| extension type over `String`, `int`, `double`, `num` or `bool` | that value | Built as `Code(value)`, so the unnamed constructor must be public and take only the value, as one positional, non-nullable parameter of the type it wraps. A factory constructor there checks the agent's values too, and throws a `ToolCallRefused` to tell the agent what is wrong. |
| `List<T>` | array | In a parameter, `T` is neither nullable nor a list, and the list has no `?` and no default. |
| plain class | object | Public, not generic, not from the SDK. Built with its public unnamed constructor, whose parameters are all named except at most one, and written through the getters of the same names. It needs no `fromJson` or `toJson`. |

Each type may be nullable. A result may also be `void`, or a `Future` or `FutureOr` of a supported type.

## Missing, null and default

| The agent | `int count = 1` | `String? note = 'new'` | `String? note` |
| --- | --- | --- | --- |
| leaves it out | `1` | `'new'` | `null` |
| sends `null` | refused | `null` | `null` |

The schema of a nullable parameter is `anyOf` the schema of its type and `{"type": "null"}`, so the agent knows it may send `null`. That is plain JSON Schema, which ag-ui-adk 0.9.0 converts for Gemini. A list of types, the shorter form, fails in ag-ui-adk 0.9.0. A parameter that is neither nullable nor has a default is required. A default is a `bool`, `int`, `double` or `String` constant, an enum value, or `null`.

A refused call does not run the method. The agent gets a message that names the argument, also for a wrong type or a key the schema does not have.

## Anything else

Maps, sets, records, generic classes and methods with type parameters are not supported. List a thin method that takes supported types and calls the real one:

```dart
/// Tags the order with [tags].
void tagOrder(List<String> tags) => setTags(tags.toSet());
```

In the same way, `.sees` can take a getter that returns a plain class made for the agent.

## AI

This package is written with AI assistance and has not had a full human review yet.
