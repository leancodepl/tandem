## Lens: responsibility in the wrong place

Principle 5 of `doc/code-quality.md` ("Keep detail with its owner") and its example "Give a concept its own type" are the rules, with principle 1 (prefer less code, reuse project code, framework APIs and maintained packages).

Look at where each new piece of logic lives:

- A class or function gathers several fields, flags or conditions about one concept that has no type of its own. That concept is the next type to extract; name it.
- Validation, parsing, diagnostics or rendering done inline in a widget, the session or an entry point instead of in the type that owns the data.
- One rule spread over several methods and fields of a class, so no single place states it.
- Two places that interpret the same format, grammar or path syntax, or that compute the same requirement separately.
- A type, error class or helper placed in a file or folder where a reader would not look for it, or a file that holds several unrelated concepts.
- Code that re-implements what Dart, Flutter, a package the repository already depends on, or the project's own code already provides.
- Code that current requirements do not need: options, branches or parameters nothing uses or asks for.

For each, say what the owner should be and what moves there.
