# Tandem

Makes an existing Flutter screen agent-aware over AG-UI: the agent sees what a Cubit lists and acts only through the methods it lists. Design: [doc/design.md](doc/design.md). Words: [GLOSSARY.md](GLOSSARY.md). Decisions: [doc/adr](doc/adr).

## Layout

- `packages/tandem`: the agent list, the AG-UI connection, the session, `TandemChat`, `ScriptedAgent`. It knows no bloc.
- `packages/tandem_bloc`: `TandemScope<C>` and the Agent Skill in `skills/`. This is what apps depend on.
- `packages/tandem_generator`: the builder behind `@TandemAgent()`. It is not a workspace member and has its own lock, which is not committed. The root `pubspec.lock` is.
- `example`: the order desk demo app (`lib/desk`) with its Google ADK agent in `example/agent` (Python, uv), the order form of the README (`lib/order_cubit.dart`) and a shopping list for the tests (`lib/shopping_list.dart`), with their generated code and tests. How to run the demo: [example/README.md](example/README.md).

## Commands

Everything goes through fvm (Flutter 3.47.6 and Dart 3.13.5, from `.fvmrc`).

```sh
fvm flutter pub get                                 # the workspace
(cd packages/tandem_generator && fvm dart pub get)  # the generator, on its own
fvm dart analyze --fatal-infos                      # not flutter analyze: it skips the leancode_lint plugin
fvm dart format --set-exit-if-changed .
(cd packages/tandem && fvm flutter test)
(cd packages/tandem_generator && fvm dart test)
(cd example && fvm dart run build_runner build)     # then git diff --exit-code -- '*.g.dart': the .g.dart files are committed
(cd example && fvm flutter test)
(cd example/agent && uv sync --locked && uv run ruff check && uv run ruff format --check && uv run pytest)
```

CI runs the same, plus a dry run of `pub publish` for each package. `publish.yml` runs by hand only.

## Rules

- Never use the null-assertion operator `!`, also not in tests or generated code. Check null with a pattern (`if (x case final y?)`), with `?.` or `??` and a real fallback, or use a type that cannot be null.
- Small files, one concept each. Named constants for real values, not for obvious JSON keys. Write the thinnest code that does the job. The code uses Dart 3.13 primary constructors and dot shorthands.
- Few tests. One focused test per behaviour or fixed defect, in the existing test file when there is one. No test that restates the implementation.
- build_runner stays 2.16.x. leancode_lint 27 lints the `.g.dart` files too.
- Nothing talks to a real model. Tests use `ScriptedAgent`, and the agent's tests use its scripted model (`TANDEM_FAKE_LLM=1`).
- When the API changes, change `README.md`, `packages/tandem_bloc/README.md` (the same file, keep them identical) and `packages/tandem_bloc/skills/tandem-bloc-agent-aware-screen/SKILL.md`. When a session rule changes, change `doc/design.md`.
- Commit messages are `task: <what>`, with no `Co-Authored-By` or other attribution.
- Never read, print or create a `.env` file. No API keys in the repo.
- Docs and comments: short sentences, no em dashes.
