## Lens: raw types where a value has meaning

Principle 5 of `doc/code-quality.md` ("Keep detail with its owner") is the rule. The maintainer treats a value with identity or meaning held in a raw type as a defect to fix, never as an advisory point.

Look at every field, parameter, return type, record and collection the change declares or widens:

- An identifier, key, code, status, name of a tool or method, amount with a unit or constrained value held in `String`, `int`, `Object`, `Object?` or `dynamic` instead of its own immutable value type. In this repository such a type is an extension type or a small class whose constructor enforces the invariant; look at how `ToolStatus` and `RunErrorCode` do it and at how the same kind of value is already typed elsewhere.
- A nullable raw value whose `null` switches a mode or means something the type does not say.
- `Map<String, dynamic>`, `Map<String, Object?>`, `List<Object?>` or decoded JSON that travels past the place it is parsed: into the session, a widget, a field or several functions. Raw input belongs in wire DTOs and forms and is parsed once at the boundary.
- A record used as an ad-hoc struct: passed between functions, stored in a field, or with more than two fields whose roles a reader has to infer.
- A protocol string, code or name typed by hand in more than one place, or by the app, instead of a constant on its type next to what produces it.
- An identity assembled by each caller instead of by one constructor.
- Adjacent positional parameters of one type whose roles a call site cannot show.
- When one such value is fixed, analogous values in the same domain left raw.

Valid exceptions: ordinary free text that is shown or sent as is; JSON that is the wire format itself inside the codec or DTO; values whose schema is owned by a spec the package implements and that only pass through.
