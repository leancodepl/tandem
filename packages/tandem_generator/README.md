# tandem_generator

Generates the code behind the `agent` list of a Tandem screen: what the agent sees and which of its methods it may call. Run it with `dart run build_runner build`.

Apps depend on [`tandem_bloc`](https://pub.dev/packages/tandem_bloc) and add this package as a dev dependency. How to use it is in the [main README](https://github.com/leancodepl/tandem#readme).

## Supported types

Parameters of the listed methods become the JSON Schema the agent fills in. Results and `.sees` getters reach the agent as JSON. For any other type the build fails and names the type and where it is.

| Dart | JSON | Rules |
| --- | --- | --- |
| `String`, `bool` | string, boolean | |
| `int`, `double`, `num` | integer, number | `15.0` is read as `15`. An `int` refuses `1.5` and doubles of 2^53 or more in size. |
| `DateTime` | ISO 8601 string | A day or time that does not exist, such as `2026-02-30`, is refused. |
| enum | the value's name | |
| extension type over `String`, `int`, `double`, `num` or `bool` | that value | Built as `Code(value)`: the unnamed constructor must be public and take only the value, as a positional parameter. A factory there checks the agent's values too. |
| `List<T>` | array | In a parameter, `T` is neither nullable nor a list, and the list has no `?` and no default. |
| plain class | object | Public, not generic, not from the SDK. Built with its public unnamed constructor, whose parameters are all named except at most one, and written through the getters named like them. No `fromJson` or `toJson`. |

Each type may be nullable. A result may also be `void`, or a `Future` or `FutureOr` of a supported type.

## Missing, null and default

| The agent | `int count = 1` | `String? note = 'new'` | `String? note` |
| --- | --- | --- | --- |
| leaves it out | `1` | `'new'` | `null` |
| sends `null` | refused | `null` | `null` |

A parameter that is neither nullable nor has a default is required. A default is a `bool`, `int`, `double` or `String` constant, an enum value, or `null`.

A refused call does not run the method. The agent gets a message that names the argument, also for a wrong type or a key the schema does not have.

## Anything else

Maps, sets, records, generic classes and methods with type parameters are not supported. List a thin method that takes supported types and calls the real one:

```dart
/// Tags the order with [tags].
void tagOrder(List<String> tags) => setTags(tags.toSet());
```

In the same way, `.sees` can take a getter that returns a plain class made for the agent.
