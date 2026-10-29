---
name: tandem
description: Set up Tandem in a Flutter app, so an agent works on a screen through the methods its buttons already call. Use when asked to add Tandem, or to let a coding agent or an in-app AI agent fill in or change a Flutter screen.
argument-hint: "[screen]"
user-invocable: true
---

# Tandem

Tandem lets an agent work on one screen of a Flutter app through the methods its state class lists, the same ones its widgets call, and the important ones wait for the user's approval. This skill checks the app, installs the skills of the `tandem` package that fit its version, and hands the work to them. Do the steps in order and check each "Done when" before the next. In a project with `.fvmrc`, run every `flutter` and `dart` command through `fvm`.

Tandem is tested with Claude Code only. Another coding agent, such as Cursor or Codex, follows the same steps: tell the user once that Tandem is not tested with it.

## 1. Check the packages

Read `pubspec.yaml`. Tandem needs `tandem` in `dependencies`, and `tandem_generator` and `build_runner` in `dev_dependencies`. Tell the user which are missing, then add them:

```sh
flutter pub add tandem
flutter pub add dev:build_runner dev:tandem_generator
```

Tandem needs Dart 3.13 (Flutter 3.47) or newer. Keep `tandem` and `tandem_generator` on the same minor version.

**Done when** all three are in `pubspec.yaml` and `flutter pub get` succeeds.

## 2. Install the package's skills

Run this every time, also when the skills are there: it installs the skills of the `tandem` version in `pubspec.lock`.

```sh
dart run skills@ get --package tandem --all
```

The command exits with 0 also when it fails, so read its output. "None of the requested packages were found in dependencies" means step 1 is not done. "Could not auto-detect agent" means the project has no folder of your skills: add `--agent` with your name, such as `--agent claude`, `--agent cursor` or `--agent codex`.

The skills land in the folder that holds this skill: `.claude/skills/`, `.cursor/skills/` or `.agents/skills/`. Check that it has these three:

- `tandem-agent-aware-screen`: the base, which lists what the agent sees and calls.
- `tandem-coding-agent`: path A.
- `tandem-in-app-agent`: path B.

The last two came with `tandem` 0.2.1. When one is missing, tell the user that their version of `tandem` is too old for it, offer `flutter pub upgrade tandem tandem_generator`, and run the command above again after the upgrade.

**Done when** the three skills are in the folder, or the user knows which version they need.

## 3. Choose the path with the user

Show the user both paths and ask which they want:

- **A, start here: your coding agent fills a screen.** You fill in a screen of the running debug app, such as a form from an e-mail, through the methods its buttons call. Debug builds only. No backend, no API key, no chat.
- **B: an in-app agent for the app's users.** The users talk to an agent through a chat, or a button such as "Fill from e-mail". It needs an AG-UI backend, or Apple's on-device model on iOS and macOS 26, which is experimental and fits only the simplest tasks.

Both need the same base, so B can come later. When the user wants both, do A first.

**Done when** the user chose A, B or both.

## 4. Choose the screen

When the request names a screen, such as `/tandem OrderScreen`, take that one. Otherwise ask, and offer the screens whose state lives in a class the widgets call, such as a Cubit, a Riverpod `Notifier` or a `ChangeNotifier`, a form first. Tandem works on one screen at a time.

**Done when** the user confirmed one screen.

## 5. Hand the work over

Read each skill's `SKILL.md` from the folder of step 2 and follow it, in this order:

1. `tandem-agent-aware-screen`, for the chosen screen.
2. `tandem-coding-agent` for A, then `tandem-in-app-agent` for B.

For a fixed demo without a backend, path B's testing step uses `ScriptedAgent`; `ScriptedAgent.repeating` handles every run with the same callback.

Build only what the chosen path needs: path A gets no chat and no backend. Ask the user wherever a skill offers a choice.

**Done when** the last step of the chosen path is done.
