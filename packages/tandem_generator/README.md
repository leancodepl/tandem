# tandem_generator

Generates the code behind the `agentCapabilities` of a Tandem screen marked `@TandemAgent()`: what the agent sees and which of its methods it may call. Run it with `dart run build_runner build`.

Apps depend on [`tandem_bloc`](https://pub.dev/packages/tandem_bloc) and add this package as a dev dependency. How to use it is in the [main README](https://github.com/leancodepl/tandem#readme).

## Supported types

Parameters of the listed methods become the JSON Schema the agent fills in. Results and `.sees` getters reach the agent as JSON. For any other type the build fails and names the type and where it is.

| Dart | JSON | Rules |
| --- | --- | --- |
| `String`, `bool` | string, boolean | |
| `int`, `double`, `num` | integer, number | `15.0` is read as `15`. An `int` refuses `1.5` and doubles of 2^53 or more in size. |
| `DateTime` | ISO 8601 string | `2026-10-23`, optionally with a time such as `T10:20`, `T10:20:59.5Z` or `T10:20+02:00`. A space may stand for the `T`, a comma for the decimal point, and the zone may be `+02`, `+0200` or `+02:00`, from `-23:59` to `+23:59`. Other forms, and a day or time that does not exist, such as `2026-02-30`, are refused. |
| enum | the value's name | |
| extension type over `String`, `int`, `double`, `num` or `bool` | that value | Built as `Code(value)`: the unnamed constructor must be public and take only the value, as a positional parameter of the type it wraps, without `?`. A factory there checks the agent's values too. |
| `List<T>` | array | In a parameter, `T` is neither nullable nor a list, and the list has no `?` and no default. |
| plain class | object | Public, not generic, not from the SDK. Built with its public unnamed constructor, whose parameters are all named except at most one, and written through the getters named like them. No `fromJson` or `toJson`. |

Each type may be nullable. A result may also be `void`, or a `Future` or `FutureOr` of a supported type.

## Missing, null and default

| The agent | `int count = 1` | `String? note = 'new'` | `String? note` |
| --- | --- | --- | --- |
| leaves it out | `1` | `'new'` | `null` |
| sends `null` | refused | `null` | `null` |

The schema marks a nullable parameter `"nullable": true`, so the agent knows it may send `null`. That keyword is OpenAPI's dialect, which Gemini reads: plain JSON Schema ignores it and refuses the `null`. JSON Schema's own form, a list of types, fails in ag-ui-adk 0.9.0. A parameter that is neither nullable nor has a default is required. A default is a `bool`, `int`, `double` or `String` constant, an enum value, or `null`.

A refused call does not run the method. The agent gets a message that names the argument, also for a wrong type or a key the schema does not have.

## Anything else

Maps, sets, records, generic classes and methods with type parameters are not supported. List a thin method that takes supported types and calls the real one:

```dart
/// Tags the order with [tags].
void tagOrder(List<String> tags) => setTags(tags.toSet());
```

In the same way, `.sees` can take a getter that returns a plain class made for the agent.
