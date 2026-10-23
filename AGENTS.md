# Tandem

Makes an existing Flutter screen agent-aware over AG-UI: the agent sees what the screen's state class lists and acts only through the methods it lists. Design: [doc/design.md](doc/design.md). Words: [GLOSSARY.md](GLOSSARY.md). Decisions: [doc/adr](doc/adr). Proposals: [doc/rfc](doc/rfc).

## Layout

- `packages/tandem`: the agent list, the AG-UI connection, the session, `TandemScope`, `TandemBridge`, `ScriptedAgent` and the Agent Skills in `skills/`. This is what apps depend on. It does not depend on bloc and has no chat widget.
- `skills/tandem`: the `/tandem` skill that apps install from this repository. It checks the app and hands the work to the package's skills.
- `packages/tandem_generator`: the builder behind `@TandemAgent()`. It is not a workspace member, so it has its own `pubspec.lock`, which is not committed. The root `pubspec.lock` is committed.
- `example`: the gallery app (`lib/gallery`), which runs six screens with scripted agents, and the order desk (`lib/desk`) with its Google ADK agent in `example/agent` (Python, uv). Also the order form of the README (`lib/order_cubit.dart`, `lib/order_screen.dart`, `lib/order_messages.dart` and `lib/status_line.dart`), with its generated code and tests, the chat that apps copy (`lib/agent_chat.dart`), and the shopping list of `packages/tandem/example/example.md` (`lib/shopping_list`). The examples of [doc/examples.md](doc/examples.md) are in `lib/recipes`, with Riverpod and provider, and their tests in `test/recipes`. `test/doc_snippets_test.dart` checks that every Dart block of the README, that doc and both packages' `example/example.md` is a verbatim part of the file its comment names. The state classes and fixtures that only tests use, such as the shopping list that holds a method open with `serverReply`, are in `test/`. How to run the gallery: [example/README.md](example/README.md).

## Commands

Everything goes through fvm (Flutter 3.47.6 and Dart 3.13.5, from `.fvmrc`).

```sh
fvm flutter pub get                                 # the workspace
(cd packages/tandem_generator && fvm dart pub get)  # the generator, on its own
fvm dart analyze --fatal-infos                      # not flutter analyze: it skips the leancode_lint plugin
fvm dart format --set-exit-if-changed .
(cd packages/tandem && fvm flutter test)
(cd packages/tandem_generator && fvm dart test)
(cd example && fvm dart run build_runner build)     # then git diff --exit-code: the generated code is committed
(cd packages/tandem && fvm dart run pigeon --input pigeons/apple_api.dart && fvm dart format lib test)  # the Swift bridge's API
(cd example && fvm flutter test)
bash tool/check_apple.sh                           # macOS 26+, no inference
(cd example/agent && uv sync --locked && uv run ruff check && uv run ruff format --check && uv run pytest)
```

CI runs the same, plus a dry run of `pub publish` and a pana score for each package. On a PR it also runs commitlint on the commits and the title, and checks the sections of the description.

## Rules

- Make every change in a dedicated Git worktree. Keep the primary checkout on a clean `main`.
- Never use the null-assertion operator `!`, also not in tests or in the code `tandem_generator` writes. Code from other generators, such as Pigeon's, is exempt: nobody edits it. Check null with a pattern (`if (x case final y?)`), with `?.` or `??` and a real fallback, or use a type that cannot be null.
- For behavior changes or refactors, read [code quality](doc/code-quality.md) before editing and apply its readability review before handoff. Spelling and formatting edits need only the relevant mechanical checks.
- Named constants for real values, not for obvious JSON keys. Exception: AG-UI wire keys in `packages/tandem/lib` use `AgUiFields` from [ag_ui.dart](packages/tandem/lib/src/protocol/ag_ui.dart). UI strings and spacing go inline at the use site, not in blocks of private constants.
- No `Widget _buildX()` methods: write a private `StatelessWidget` with a const constructor.
- The code explains itself. Write a comment only for a why the code cannot show (a protocol quirk, an upstream bug, an invariant), in one short line, with a link when there is one. A doc comment says more than the name and type, or it is not written. The same holds for the Python agent: docstrings only where they add something, type hints, ruff clean.
- Few tests. One focused test per behaviour or fixed defect, in the existing test file when there is one. No test that restates the implementation.
- build_runner stays 2.16.x. leancode_lint 27 lints the `.g.dart` files too.
- Nothing talks to a real model. Tests use `ScriptedAgent`, and the agent's tests use its scripted model (`Settings(fake_llm=True)`).
- When the API changes, change `README.md`, `packages/tandem/README.md` (a copy, except the media under "Try it without a key"), `packages/tandem/example/example.md`, the skills in `packages/tandem/skills` and `skills/tandem`, and the examples in `example/lib/recipes` with `doc/examples.md`. When a session rule changes, change `doc/design.md`.
- Never read, print or create a `.env` file. No API keys in the repo.
- Docs and comments: short sentences, plain words, no em dashes. Say what is true, not how it came to be.

## Commits and pull requests

- Commits follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), with the types, scopes and length in [.commitlintrc.yml](.commitlintrc.yml). The scope is there only when the change stays in one package or `example`: `fix(tandem): keep Stop unavailable while an approved method runs`.
- The subject is lowercase imperative. A body only for a why the diff cannot show, in a few lines.
- A change to the public API of a package that breaks apps gets `!` and a `BREAKING CHANGE:` footer that says what an app changes.
- One commit per logical change that builds and passes the tests on its own, such as a refactor and then the fix that needs it. Its test, docs and generated code go in the same commit. Most PRs need one to three.
- Review fixes go into the commit they fix: `git commit --fixup`, then `git rebase --autosquash`.
- The PR title has the form of a commit subject. The description fills the sections of [.github/pull_request_template.md](.github/pull_request_template.md) and follows its hints.
- A commit an AI agent wrote ends with a `Co-Authored-By:` trailer naming the agent and its model, such as `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Only a commit a human reviewed in full can carry no attribution. The PR description has no attribution line.
