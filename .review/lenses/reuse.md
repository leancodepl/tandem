## Lens: hand-written code that a dependency or the project already provides

The rules are in `AGENTS.md` ("Before writing a helper, look for it in Dart, Flutter or a maintained package") and principle 1 of `doc/code-quality.md` ("Reuse project code and framework APIs. Prefer a proven, maintained package that meets the requirements over a custom equivalent").

For each helper, parser, schema, data structure or algorithm the change writes by hand:

- Look for the same thing in the packages the change's package depends on, directly or through another dependency. The `pubspec.yaml` of the package lists them, `pubspec.lock` at the root gives their versions, and their sources are in `~/.pub-cache/hosted/pub.dev/<name>-<version>/lib`. Read the public API of the relevant ones.
- Look for it in the Dart and Flutter SDKs and in this repository's own code.
- Report it when an existing API does the same job and the hand-written code would shrink or disappear by using it, or when the change reimplements a format, schema or grammar that a dependency already models.

For each, name the existing API (package, library, class or function) and what the code would look like with it. Leave out code where the existing API does not fit, and say nothing about adding a new dependency unless it is already in `pubspec.lock`.
